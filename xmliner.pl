#! /usr/bin/perl
# 以面向行分析的方式处理规范的 xml 数据配置文件
#
# 该文件主要当作一种模板框架程序示范
# 其本身的功能仅是重新打印输入的 xml 源文本
# 并调整缩进层次，保持原属性顺序
#
# 要求的 xml 数据文件规范性：
# 1) 一行最多有一个元素
# 2) 元素没有混合内容，即子元素与文本内容不同时出现
# 3) 主要三种元素格式
#  3.1) 数据保存在标签文本中
#       <tag>text</tag>
#  3.2) 数据保存在属性列表中
#       <tag key1="val" key2="val" ... />
#  3.3) 包含子元素结构
#       <tag [attrs]>
#         <<child-tag>>
#       </tag>
#  非混合内容限制 text 与子元素同时存在，但 text 与属性可共存
#  且要求标签 tag 与属性或文本在同一行
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
	&OnOpenDefault;
}

sub HandleTagClose
{
	&OnCloseDefault;
}

sub HandleOthers
{
	&PreserveOthers;
}

sub HandleBegin
{
	# body...
}

sub HandleEnd
{
	# body...
}


