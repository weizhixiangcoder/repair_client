SITE=2												#添加随机串位置1 前  2 后   默认1
SIZE=3												#随机串长度1 ~ 10			默认5
STRING=4											#1 随机串为纯数字 2 随机串为纯字母 3 随机串为数字字母混合 4 整个文件名替换(md5 path/file),长度SIZE=32 		默认3
NO_REPLACE_DIR="base/res:base/src"				#忽略目录下文件名改名， 相对路径用:分割, 默认code目录下
NO_REPLACE_FILE="client/res/Bag/bt_add.png:client/res/Bag/bt_use_0.png"									#忽略文件， 相对路径用:分割
FIX_REPLACE_DIR="game/yule/sparrowchy"									#固定相同随机串目录， 用同一个随机串， 相对路径用:分割， 该目录文件当STRNIG=4依然为数字字母混合生成的随机串


