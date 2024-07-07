# **Discourse Image Enhancement** 插件

简体中文 | [English](README.md)

## 插件介绍

基于 AI 的 Discourse 图片分析与搜索插件。自动对 Discourse 中的图片进行分析，特点如下：

* 基于图片文字、图片内容进行图片搜索
* 自动举报含有特定文字内容的图片

## 安装

请参考 [Discourse 官方安装插件教程](https://meta.discourse.org/t/install-a-plugin/19157) 安装本插件。在`app.yml`文件中添加如下内容：

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/ShuiyuanSJTU/discourse-image-enhancement
```

此外，本插件还需要后端 AI 推理服务，请参考[部署指南](https://github.com/ShuiyuanSJTU/discourse-image-enhancement-service)。

## 配置

在站点设置启用`image enhancement enabled`与`image search enabled`，并将`image enhancement service endpoint`设置为后端服务地址。