# **Discourse Image Enhancement** Plugin

[简体中文](README.zh_CN.md) | English

## Plugin Summary

An AI-powered plugin for Discourse that provides image analysis and search. Automatically analyzes images in Discourse with the following features:

* Image search based on text and image content
* Automatically flag images containing specific text content

## Installation

Please refer to the [Discourse Official Plugin Installation Guide](https://meta.discourse.org/t/install-a-plugin/19157) to install this plugin. Add the following content to the `app.yml` file:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/ShuiyuanSJTU/discourse-image-enhancement
```

Additionally, this plugin requires a backend AI inference service. Please refer to the [Deployment Guide](https://github.com/ShuiyuanSJTU/discourse-image-enhancement-service).

## Configuration

Enable `image enhancement enabled` and `image search enabled` in site settings, and set the `image enhancement service endpoint` to the backend service address.
