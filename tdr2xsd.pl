#! /usr/bin/perl
# 将 tdr 的 xml 描述文件转为形式等效的 xsd 文件
# 输出的 xsd 可用 xml 可视编辑器如 XMLSpy 或 Oxygen XML Editor 打开，
# 在模式视图中以框图的形式查看数据结构层次
#
# 脚本运行于标准输入输出，宜结合管道与/或重定向一起工作
# 如将数据库的 xml 转化为 xsd 架构，可用如下命令
#   cat database.xml | tdr2xsd.pl > database.xsd
#
# 注：若 xml 文件间的结构有相互依赖关系
# 可将多个 xml 文件都放在命令行输入该脚本
# 否则虽然该脚本能正常运行，但结果 xsd 文件可能部分非法
# 不过 database.xml 文件几乎是自封闭的，没有引用其他 xml 中定义的结构
#
# 注：要求输入 xml 源文件格式规范
# 因未使用复杂的 xml 解析模块，只用到基本的 perl 文本解析语法
#
# 转化简要对应：
# 1) tdr 的 struct 转为 xsd 的顺序容器(sequence)的复合类型(complexType)
# 2) tdr 的 union  转为 xsd 的选择容器(choice)的复合类型(complexType)
# 3) entry 转为元素(xs:element)
# 4) tdr 的简单类型转为合适的 xsd 数据类型 (xs:int 等)
# 5) 会分析 count 引用的宏，以标记元素的最大允许出现次数(maxOccurs)
# 6) 提取 desc 注释文本，转为 xsd 的注释(annotation)
# 7) 其他数据暂时忽略不处理
#
# *) 初输出的 xsd 文本没有缩进，但专门的 xml 编辑器都应会有缩进优化的功能
#    或再管道至 | xmliner.pl 可处理缩进
#
# tsl@2016-03

use strict;
use warnings;

# @TAG 保存当前的 xml 标签名及属性名，%ATS 保存属性值
# $TAG[0] 就是标签名，$TAG[1] ... $TAG[i] 是源序的属性名
# $ATS{$TAG[i]} 是第 i 个属性的值
# $ATS{$TAG[0]} 是标签本身的文本值
my @TAG = ();
my %ATS = ();

# @TREE 保存历史标签名堆栈，栈顶是当前标签，栈底是 root
my @TREE = ();

# 当前行发现开标签或闭标签，可能单行同时存在
my $OPEN = 0;
my $CLOSE = 0;
# 当前 xml 文本行
my $XML = "";

# 每层缩进空白
my $LEAD = "\t";

# --- 主循环程序 --- #
&HandleBegin;
while (<STDIN>)
{
	chomp;
	s/^\s*//;
	s/\s*$//;

	$XML = $_;
	$OPEN = &IsTagOpen($_); 
	$CLOSE = &IsTagClose($_);
	if ($OPEN) {
		&HandleTagOpen;
	}
	elsif ($CLOSE) {
		&HandleTagClose;
	}
	else {
		&HandleOthers;
	}
	
}
&HandleEnd;
# --- 主循环结束 --- #

sub IsTagOpen
{
	my $xml = shift;
	return 0 unless $xml =~ /^\<\s*(\w+)\s*/;

	my $tag = $1;
	@TAG = ();
	%ATS = ();
	push @TAG, $tag;
	push @TREE, $tag;

	my @fields = $xml =~ /\s+(\w+)\s*\=\s*"(.+?)"/g;
	while (@fields) {
		my $key = shift @fields;
		my $val = shift @fields;
		push @TAG, $key;
		$ATS{$key} = $val;
	}

	if ($xml =~ /^\<\s*${tag}.*\>\s*(.*?)\s*\<\s*\/\s*${tag}\s*\>$/) {
		my $text = $1;
		$ATS{$tag} = $text;
	}

	return 1;
}

sub IsTagClose
{
	my $xml = shift;
	my $tag = "";
	if ($xml =~ /\<\s*\/\s*(\w+)\s*\>$/) {
		$tag = $1;
	} elsif	($xml =~ /^\<\s*(\w+).*\/\s*\>$/){
		$tag = $1;
	} else {
		return 0;
	}
	my $top = pop @TREE;
	print "closing tag <$tag> dismatch poped tag<$top>\n" if $tag ne $top;
	$TAG[0] = $tag;
	return 1;
}

sub OnOpenDefault
{
	my $xml = "";
	my $lead = "";

	my $tag = $TAG[0];
	my $text = $ATS{$tag};

	my $ats = "";
	for (my $i = 1; $i < @TAG; $i++) {
		$ats .= " $TAG[$i]=\"$ATS{$TAG[$i]}\"";
	}
	
	if ($CLOSE) { # 单行自闭合
		if (defined($text) && length($text)) {
			$xml = "<${tag}${ats}>$text</$tag>";
		}
		else {
			$xml = "<${tag}${ats}/>";
		}
		$lead = $LEAD x @TREE;
	}
	else { # 纯开标签
		$xml = "<${tag}${ats}>";
		$lead = $LEAD x (@TREE - 1);
	}
	
	print "${lead}${xml}\n";
}

sub OnCloseDefault
{
	return if $OPEN; # 单行自闭合，工作已在开标签处理函数中完全
	my $tag = $TAG[0];
	my $lead = $LEAD x @TREE;
	my $xml = "</$tag>";

	print "${lead}${xml}\n";
}

sub PreserveOthers
{
	my $lead = $LEAD x @TREE;
	print "$lead$XML\n";
}

sub HandleTagOpen
{
	# &OnOpenDefault;
	my $tag = $TAG[0];
	if ($tag eq "struct") {
		&OnStructOpen;
	}
	elsif ($tag eq "union") {
		&OnUnionOpen;
	}
	elsif ($tag eq "entry") {
		&OnEntry;
	}
	elsif ($tag eq "macro") {
		&OnMacro;
	}
	
}

sub HandleTagClose
{
	# &OnCloseDefault;
	my $tag = $TAG[0];
	if ($tag eq "struct") {
		&OnStructClose;
	}
	elsif ($tag eq "union") {
		&OnUnionClose;
	}
}

sub HandleOthers
{
	# &PreserveOthers;
}

# tdr 数据类型与 xsd 数据类型的映射表
my %types;
# 宏定义
my %macros;

sub HandleBegin
{
	&InitTable;

	print <<EOF;
<?xml version="1.0" encoding="gb2312" standalone="yes"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified" attributeFormDefault="unqualified">
EOF
	return 1;
}

sub HandleEnd
{
	print "</xs:schema>\n";
	return 1;
}

sub InitTable
{
	%types = (
		byte => "byte",
		char => "byte",
		tinyint => "byte",
		tinyuint => "unsignedByte",
		smallint => "short",
		smalluint => "unsignedShort",
		int => "int",
		uint => "unsignedInt",
		bigint => "long",
		biguint => "unsignedLong",
		float => "float",
		double => "double",
		date => "date",
		time => "time",
		datetime => "datetime",
		string => "string",
		wchar => "unsignedShort",
		wstring => "string",
		ip => "string",
		void => "anyType",
	);

	%macros = ();
}

# 提取宏定义，但未处理宏组
sub OnMacro
{
	my $name = $ATS{name};
	my $value = $ATS{value};
	$macros{$name} = $value if defined($name) && $name;
}

# 每个 <entry> 转为 <xs:element>
sub OnEntry
{
	my $name = $ATS{name};
	my $type = $ATS{type};
	my $xtype = $types{lc($type)};
	$type = "xs:$xtype" if $xtype;
	my $doc = $ATS{cname} || $ATS{desc};

	my $xml = "<xs:element name=\"$name\" type=\"$type\"";
	if ($ATS{count}) {
		my $count = $macros{$ATS{count}};
		$count = "unbounded" unless $count;
		$xml .= " maxOccurs=\"$count\"";
	}
	
	if ($doc) {
		$xml .= ">\n";
		$xml .= "<xs:annotation>\n";
		$xml .= "<xs:documentation>$doc</xs:documentation>\n";
		$xml .= "</xs:annotation>\n";
		$xml .= "</xs:element>\n";
	}
	else {
		$xml .= "/>\n";
	}
	
	print $xml;
}

sub OnStructOpen
{
	my $name = $ATS{name};
	my $doc = $ATS{desc} || "";
	print <<EOF;
<xs:complexType name="$name">
<xs:annotation>
<xs:documentation>$doc</xs:documentation>
</xs:annotation>
<xs:sequence>
EOF
	return 1;
}

sub OnStructClose
{
	print <<EOF;
</xs:sequence>
</xs:complexType>
EOF
	return 1;
}

sub OnUnionOpen
{
	my $name = $ATS{name};
	my $doc = $ATS{desc};
	print <<EOF;
<xs:complexType name="$name">
<xs:annotation>
<xs:documentation>$doc</xs:documentation>
</xs:annotation>
<xs:choice>
EOF
	return 1;
}

sub OnUnionClose
{
	print <<EOF;
</xs:choice>
</xs:complexType>
EOF
	return 1;
}

