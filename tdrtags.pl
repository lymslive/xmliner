#! /usr/bin/perl
# 生成 tdr 描述文件 xml 源文件中的 tag 列表
#
# 要求 xml 源文件规范
# 标准输入：xml 文件名列表，一行一个
# 标准输出：tags 文件内容
#
# 示例用法：
#   ls *.xml | tdrtags.pl | sort > tags
#
# tags 文件格式：参考 vim :help tagsrch.txt
#  <tagname><Tab><filename><Tab></search-cmd/>;"<Tab>{:kind}<Tab>{:value}
#
# 提取 tdr-xml 的内容：
# *) struct 结构体名，kind='s', value=其包含的entry数目
# *) union  联合体名，kind='u', value=其包含的entry数目
# *) macrosgroup 宏组名，kind='g', value=其包含的macro数目
# *) macro  宏定义名，kind='m', value=就是宏的值
# *) entry  不提取到 tag 中，但会在同个范围内计数
#
# 注意：
# 该脚本生成的 tag 按源文件的顺序输出，如果要排序，可调用其他程序
# 简单的 sort 命令即可按文本行排序
#
# tsl@2016/03

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

# 当前处理的文件
my $FILE = "";

# --- 主循环程序 --- #
&HandleBegin;
while (<STDIN>)
{
	chomp;
	s/^\s*//;
	s/\s*$//;

	$FILE = $_;
	open BUFF, $FILE or next;

	while (<BUFF>) {
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

	close BUFF;
}
&HandleEnd;
# --- 主循环结束 --- #

# [\w:] xml 标签与属性名应支持 : 命名空间
sub IsTagOpen
{
	my $xml = shift;
	return 0 unless $xml =~ /^\<\s*([\w:]+)\s*/;

	my $tag = $1;
	@TAG = ();
	%ATS = ();
	push @TAG, $tag;
	push @TREE, $tag;

	my @fields = $xml =~ /\s+([\w:]+)\s*\=\s*"(.+?)"/g;
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
	if ($xml =~ /\<\s*\/\s*([\w:]+)\s*\>$/) {
		$tag = $1;
	} elsif	($xml =~ /^\<\s*([\w:]+).*\/\s*\>$/){
		$tag = $1;
	} else {
		return 0;
	}
	my $top = pop @TREE;
	print "closing tag <$tag> dismatch poped tag<$top>\n" if $tag ne $top;
	$TAG[0] = $tag;
	return 1;
}

sub HandleTagOpen
{
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
	elsif ($tag eq "macrosgroup") {
		&OnGroupOpen;
	}
}

sub HandleTagClose
{
	my $tag = $TAG[0];
	if ($tag eq "struct") {
		&OnStructClose;
	}
	elsif ($tag eq "union") {
		&OnUnionClose;
	}
	elsif ($tag eq "macrosgroup") {
		&OnGroupClose;
	}
}

sub HandleOthers
{
}

# entry 项计数
my $entry;
# 在宏组中的宏计数
my $macro_in_group;
# 在 tags 文件中的类型标记
my %kinds;

sub HandleBegin
{
	$entry = 0;
	$macro_in_group = -1;
	%kinds = (
		macro => "m",
		group => "g",
		struct => "s",
		union => "u",
	);
}

# 在最后打印一行标记行，排序后一般会置顶表示已排序
# 然而，有些 sort 要 export LC_ALL=C 才是严格字符序排列
sub HandleEnd
{
	print <<EOF;
!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
EOF
}


sub OnMacro
{
	my $name = $ATS{name};
	my $value = $ATS{value};
	my $kind = $kinds{macro};
	print <<EOF;
$name	$FILE	/<macro name="$name"/;"	$kind	value:$value
EOF

	$macro_in_group++ if $macro_in_group >= 0;
}

sub OnEntry
{
	$entry++;
}

sub OnStructOpen
{
	$entry = 0;
	my $name = $ATS{name};
	my $kind = $kinds{struct};
	print "$name	$FILE	/<struct name=\"$name\"/;\"	$kind	";
}

# 只有当 </struct> 时才能确定里面有多少 <entry>
sub OnStructClose
{
	my $value = $entry;
	print "value:$value\n";
}

sub OnUnionOpen
{
	$entry = 0;
	my $name = $ATS{name};
	my $kind = $kinds{union};
	print "$name	$FILE	/<union name=\"$name\"/;\"	$kind	";
}

sub OnUnionClose
{
	my $value = $entry;
	print "value:$value\n";
}

# macrosgroup 情况较特殊，其内的 macro 也要生成 tag，需借助中间变量
my $group_tag_string = "";
sub OnGroupOpen
{
	$macro_in_group = 0;
	my $name = $ATS{name};
	my $kind = $kinds{group};
	$group_tag_string =  "$name	$FILE	/<macrosgroup name=\"$name\"/;\"	$kind";
}

sub OnGroupClose
{
	my $value = $macro_in_group;
	print "$group_tag_string	value:$value\n";
	$macro_in_group = -1;
}

