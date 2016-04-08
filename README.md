# xmliner

基于行规范格式的用于配置数据的简单 xml 文件，
用 perl 实现的简单解析脚本。
不依赖 perl 的其他 xml 解析模块，
主要利用 perl 正则表达式单次扫描处理简单的 xml 文件。

## 简单的 xml 数据文件规范性：
* 一行最多有一个元素
* 元素没有混合内容，即子元素与文本内容不同时出现
* 主要三种元素格式

 1. 数据保存在标签文本中
      <tag>text</tag>
 1. 数据保存在属性列表中
      <tag key1="val" key2="val" ... />
 1. 包含子元素结构
      <tag [attrs]>
        <<child-tag>>
      </tag>

 非混合内容限制 text 与子元素同时存在，但 text 与属性可共存，
 且要求标签 tag 与属性或文本在同一行。

这种数据配置的 xml 文件一般是手动编辑或借助 xml 编辑器编辑，很容易满足上述规范
格式。
