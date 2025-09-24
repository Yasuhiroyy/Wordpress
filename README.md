# MultipassでWordPressの構築をする

## 概要
Multipassを利用してWordPressを構築する流れを紹介します

## 構成概要
- **ホスト OS**: macOS
- **仮想化ツール**: [Multipass](https://multipass.run/)（Ubuntu 20.04 LTS）
- **Web Server**: Nginx
- **Application**: PHP 8.3
- **Database**: MySQL 8.0
- **自動バックアップ**: `cron` を用いた MySQL 全体の自動バックアップスクリプト付き

# 構築方法
## Linuxサーバー上でユーザー作成
ローカルから仮想マシンへ移動
```
(base)  % multipass shell ubuntu-dev01
```
mentaというユーザーを作成
```
sudo useradd menta
```
### パスワードなしでsudo を実行可能 にする
エディターを開く
```
sudo visudo
```
ファイルの末尾に追加
```
menta ALL=(ALL) NOPASSWD:ALL
```
## ssh鍵認証の設定
### 鍵の配置場所
PC側（ローカル）に秘密鍵を置き、接続先のサーバー側（今回は ubuntu）に公開鍵を置くことで成り立つ
### ローカルで鍵生成
```
(base)  % ssh-keygen -t rsa -b 4096
```
ファイル名/ファイルパスを指定することができ、指定したファイル名でSSH鍵が作成される
```
Generating public/private rsa key pair.

#以下,Enterのみを押下して進む(設定なしの状態で進む)
Enter file in which to save the key (/c/Users/PC_User/.ssh/id_rsa):
#~/.ssh/id_rsa        ← 秘密鍵
#~/.ssh/id_rsa.pub    ← 公開鍵

Enter passphrase (empty for no passphrase):
```

### 公開鍵をサーバー側へ保存する
公開鍵の内容をコピーする
```
cat ~/.ssh/id_rsa.pub
#表示された ssh-rsa AAAAB3... から始まる文字列を全てコピー
```
 .ssh ディレクトリ作成と設定
```
sudo mkdir -p /home/menta/.ssh
sudo chmod 700 /home/menta/.ssh
#chmod 700：menta 以外がアクセスできないようにする

sudo chown menta:menta /home/menta/.ssh
#chown：所有者を menta ユーザーに設定
```
authorized_keys に公開鍵を登録
```
sudo vi /home/menta/.ssh/authorized_keys
#すでに鍵がある場合は改行して末尾に追加
```

ファイルのパーミッションと所有者設定
```
sudo chmod 600 /home/menta/.ssh/authorized_keys
sudo chown menta:menta /home/menta/.ssh/authorized_keys
#SSHはこの権限でないと無視されるか接続拒否される
```
SSH サーバー再起動
```
sudo systemctl restart ssh
```

ローカル（Mac）から接続確認
```
ssh menta@自身のIPアドレス
#パスワードなしで接続できれば成功！
#初回は「Are you sure you want to continue connecting?」と出たら yes と入力
```

## Nginxのインストール、設定
### Nginxのインストール
サーバー上にインストール
```
# パッケージリストの更新
sudo apt update

# Nginxのインストール
sudo apt install nginx

# Nginxの起動確認
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx
```
### Nginxの設定
nginx.confに設定を追記する
```
sudo vi /etc/nginx/nginx.conf
```
以下を貼り付け設定する
```
#Nginxが起動する際の設定
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
 
include /usr/share/nginx/modules/*.conf;

# リクエストを受け付ける準備の設定
events {
    worker_connections 1024;
}

#ウェブサイトの中身をどう扱うかの設定
http {
 
    include /etc/nginx/mime.types;
 
    log_format custom_log '
    [nginx] time:$time_iso8601
    server_addr:$server_addr
    host:$host
    method:$request_method
    reqsize:$request_length
    uri:$request_uri
    query:$query_string
    status:$status
    size:$body_bytes_sent
    referer:$http_referer
    ua:$http_user_agent
    forwardedfor:$http_x_forwarded_for
    reqtime:$request_time
    apptime:$upstream_response_time';
 
    gzip on;
    gzip_types text/plain text/css application/json
application/javascript application/xml text/xml application/
x-javascript text/javascript image/svg+xml;
    gzip_min_length 1000;
    gzip_comp_level 6;
 
    include /etc/nginx/conf.d/*;
 
}
```



```

```

![WordPress画面](./images/WordPress.png)
