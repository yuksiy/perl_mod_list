# perl_mod_list

## 概要

Perlモジュールの一覧表示

## 使用方法

### perl_mod_list.pl

Perlの変数「@INC」に設定されているディレクトリを検索し、
インストールされているモジュールのディレクトリ・名前・バージョンを一覧表示します。

    $ perl_mod_list.pl -s dir,name,ver

### その他

* 上記で紹介したツールの詳細については、「ツール名 --help」を参照してください。

## 動作環境

OS:

* Linux
* Cygwin

依存パッケージ または 依存コマンド:

* make (インストール目的のみ)
* perl
* [common_pl](https://github.com/yuksiy/common_pl)

## インストール

ソースからインストールする場合:

    (Linux, Cygwin の場合)
    # make install

fil_pkg.plを使用してインストールする場合:

[fil_pkg.pl](https://github.com/yuksiy/fil_tools_pl/blob/master/README.md#fil_pkgpl) を参照してください。

## インストール後の設定

環境変数「PATH」にインストール先ディレクトリを追加してください。

## 最新版の入手先

<https://github.com/yuksiy/perl_mod_list>

## License

MIT License. See [LICENSE](https://github.com/yuksiy/perl_mod_list/blob/master/LICENSE) file.

## Copyright

Copyright (c) 2010-2017 Yukio Shiiya
