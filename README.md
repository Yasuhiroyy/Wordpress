# MultipassでWordPressの構築をする

# 構成図
# 全体像
![スクリーンショット 2025-08-28 23.38.04.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/4081358/d5ee3274-c693-4755-b587-c0b369b2a408.png)

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

## Mysqlインストール

Ubuntu仮想マシンでMySQL 8.0をインストールするには、`apt` コマンドを使用します。

1. まず、パッケージリストを更新します。
    
    ```java
    sudo apt update
    ```
    
2. 次に、MySQLサーバーをインストールします。
    
    ```java
    sudo apt install mysql-server
    ```
    
    - インストールが終わったらMySQLサービスを起動・自動起動設定します。
    
    ```
    sudo systemctl start mysql
    sudo systemctl enable mysql
    
    ```
    

MySQL（またはMariaDB）の全体的な設定を記述するためのファイル

```java
sudo vi /etc/mysql/mysql.conf.d/mysqld.cnf
```

- `mysqld` = レストランの厨房（実際に料理＝SQL処理を作る人）
- `mysql` = お客さんが注文する窓口（SQL文を送るツール）
- `mysqld.cnf` = 厨房のレシピ・ルールブック（設定ファイル）

[mysqld] の下に以下を追加

```java
[mysqld]
user            = mysql
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
datadir = /var/lib/mysql
socket = /var/run/mysqld/mysqld.sock
log-error = /var/log/mysql/error.log
pid-file = /var/run/mysqld/mysqld.pid
```

### `character-set-server = utf8mb4`

- **意味**：MySQLサーバーがデフォルトで使う文字コード。
- **目的**：絵文字や多言語対応のために `utf8mb4` を使う（※`utf8`より上位互換）。

---

### `collation-server = utf8mb4_unicode_ci`

- **意味**：文字列の比較やソートに使う「照合順序」。
- **目的**：`utf8mb4` 文字コードに対して、Unicode準拠で大文字・小文字を区別しない (`ci = case-insensitive`) 比較を行う。

---

### `datadir = /var/lib/mysql`

- **意味**：データベースのデータが保存されるディレクトリのパス。
- **目的**：テーブルやスキーマのデータファイルがここに保存される。

---

### `socket = /var/run/mysqld/mysqld.sock`

- **意味**：**Unixドメインソケット**のパス（MySQLクライアントとサーバー間の通信に使う）。
- **目的**：ローカル通信をTCP/IPではなく、ソケットファイル経由で高速・安全に行う。

---

### `log-error = /var/log/mysql/error.log`

- **意味**：エラーログの出力先ファイル。
- **目的**：MySQLの起動・停止・接続エラーなどの情報を記録しておく。

---

### `pid-file = /var/run/mysqld/mysqld.pid`

- **意味**：MySQLサーバーのプロセスID（PID）を記録するファイル。
- **目的**：プロセス管理のため。再起動や停止時にこのPIDを参照することで、正しいプロセスを操作できる。

---

**MySQLサービスを再起動する:**
設定を反映させるには、MySQLサービスを再起動する必要があります。

```java
sudo systemctl restart mysql
```

## **データベースの設定**

### MySQLにログインを試みる

### `sudo` を使ってシステム認証でログインを試す

`sudo` を使ってシステム（Linux OS）の認証情報でMySQLにログインできることがあります。

```java
sudo mysql
```

---

### ステップ3: ログイン後のプロンプトと次のアクション

どちらかの方法でログインに成功すると、以下のようなMySQLのプロンプトが表示されます。

```java
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is XX
Server version: 8.0.42-0ubuntu0.24.04.1 Ubuntu

Copyright (c) 2000, 2024, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>
```

この `mysql>` プロンプトが表示されれば、MySQLサーバーへの接続は成功です！

### 1.

```java
mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'Menta_pw1234';
```

- `ALTER USER` コマンドで、rootユーザーのパスワードを変更します。
- `'Menta_pw1234'` は新しいパスワード。

### 2.

```java
CREATE DATABASE wordpress_db CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

- **目的**: WordPressが使用する**新しいデータベースを作成**します。
- **詳細**: `CREATE DATABASE` はデータベースを新規作成するコマンドです。`wordpress_db` がデータベースの名前です。`CHARACTER SET utf8mb4` は、このデータベースで使用する文字コードを**`utf8mb4`**に設定します。`COLLATE utf8mb4_general_ci` は、その文字コードにおける文字列の比較・ソート（並べ替え）ルールを**`utf8mb4_general_ci`**に設定します。
- **なぜ必要か**: WordPressは、投稿、コメント、ユーザー情報などのすべてのデータをデータベースに保存します。このコマンドで、WordPress専用の「箱」を用意するわけです。`utf8mb4`は絵文字を含む多様な文字をサポートするために必須です。

### 3.

```java
mysql> CREATE USER 'menta'@'localhost' IDENTIFIED BY 'Menta_pw1234';
```

- **目的**: WordPressがデータベースに接続するために使用する**新しいMySQLユーザーを作成**します。
- **詳細**: `CREATE USER` はMySQLに新しいユーザーを作成するコマンドです。`'menta'@'localhost'` は、`localhost`から接続する**`menta`**という名前のユーザーを作成することを示します。`IDENTIFIED BY 'Menta_pw1234'` で、そのユーザーのパスワードを`'Menta_pw1234'`に設定しています。
- **なぜ必要か**: WordPressをrootユーザーでデータベースに接続させるのはセキュリティ上非常に危険です。rootユーザーはデータベースに対する全権限を持つため、もしWordPressの脆弱性が悪用された場合、データベース全体が破壊される可能性があります。WordPress専用のユーザーを作成し、そのユーザーに必要最小限の権限だけを与えるのがベストプラクティスです。

### 4.

```java
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'menta'@'localhost';
```

- **目的**: 作成したWordPress用ユーザー（`menta`）に、先ほど作成した**`wordpress_db`データベースに対するすべての権限を付与**します。
- **詳細**: `GRANT` はユーザーに権限を与えるコマンドです。`ALL PRIVILEGES` は、対象データベースにおけるすべての操作（データの読み書き、テーブルの作成・削除など）を許可します。`ON wordpress_db.*` は、`wordpress_db`というデータベースのすべてのテーブル（`.*`）に対して権限を適用することを示します。`TO 'menta'@'localhost'` は、権限を付与する対象ユーザーと接続元を指定します。
- **なぜ必要か**: `menta`ユーザーを作成しただけでは、まだ何の権限も持っていません。WordPressがデータベースを操作（テーブル作成、データ挿入・更新・削除など）できるように、この権限付与が必要です。

### 5.

```java
mysql> FLUSH PRIVILEGES;
```

- **目的**: MySQLの**権限キャッシュを再読み込み**します。
- **詳細**: MySQLは、パフォーマンスのためにユーザーや権限の情報をメモリにキャッシュしています。`GRANT`や`REVOKE`（権限剥奪）などの権限関連のコマンドを実行した後、このキャッシュを更新しないと、変更がすぐに反映されないことがあります。
- **なぜ必要か**: 新しいユーザーや権限の設定が、MySQLサーバーに即座に認識され、有効になるようにするために実行します。

### 6. `mysql> EXIT;`

- **目的**: MySQLのコマンドラインモニターを終了し、シェルに戻ります。

---

これらのコマンドを実行することで、WordPressをインストールするためのMySQL側の準備が整います。WordPressのインストール時に、この`wordpress_db`データベース名、`menta`ユーザー名、そして`Menta_pw1234`パスワードを使用することになります。


## WordPressのダウンロードと設定 wp-config.php
```java
sudo mkdir -p /var/www/wp.techbull.cloud　＃　ドキュメントルートのとこ
cd /var/www/wp.techbull.cloud
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzvf latest.tar.gz
sudo mv wordpress/* ./
sudo cp wp-config-sample.php wp-config.php
sudo rm -rf wordpress latest.tar.gz wp-config-sample.php
sudo chown -R www-data:www-data /var/www/wp.techbull.cloud
sudo find /var/www/wp.techbull.cloud -type d -exec chmod 755 {} \;
sudo find /var/www/wp.techbull.cloud -type f -exec chmod 644 {} \;
```

### 1. ディレクトリ移動

```bash
cd /var/www/wp.techbull.cloud

```

- WordPress を配置するディレクトリに移動しています
- ここを作業ディレクトリとして設定

---

### 2. WordPress をダウンロード

```bash
sudo wget https://wordpress.org/latest.tar.gz

```

- WordPress の最新版の圧縮ファイル（tar.gz）を公式サイトからダウンロード
- `sudo` は所有者権限の関係で必要な場合があります

---

### 3. 圧縮ファイルを展開

```bash
sudo tar -xzvf latest.tar.gz

```

- ダウンロードした `latest.tar.gz` を解凍
- `wordpress/` というディレクトリが作られ、その中に WordPress のファイルが展開される

---

### 4. 展開した中身を上の階層に移動

```bash
sudo mv wordpress/* ./

```

- `wordpress/` 内のファイル・ディレクトリを **現在のディレクトリ (`/var/www/wp.techbull.cloud`) に移動**
- 展開後の余計な階層をなくす
    
    [何が入ってる？何をやってる？](https://www.notion.so/25e1c69de843806aa2bde39ad2c71599?pvs=21)
    

---

### 5. 設定ファイルのコピー

```bash
sudo cp wp-config-sample.php wp-config.php

```

- WordPress のサンプル設定ファイルをコピーして、本番用設定ファイルを作成
- この後、データベース情報などを `wp-config.php` に書き込む

---

### 6. 不要ファイルの削除

```bash
sudo rm -rf wordpress latest.tar.gz wp-config-sample.php

```

- 展開済みの `wordpress/` ディレクトリやダウンロードファイル、サンプル設定ファイルを削除
- ディレクトリを整理してスッキリさせる

---

### 7. 所有者を Nginx/PHP-FPM 権限に変更

```bash
sudo chown -R www-data:www-data /var/www/wp.techbull.cloud

```

- WordPress のファイルとディレクトリの所有者を `www-data` に統一
- Ubuntu では Nginx と PHP-FPM が `www-data` で動作するため、書き込み権限の問題を防ぐ

---

### 8. ディレクトリのパーミッションを設定

```bash
sudo find /var/www/wp.techbull.cloud -type d -exec chmod 755 {} \;

```

- ディレクトリだけに対して権限 755 を付与
    - 所有者: 読み書き実行
    - グループ・その他: 読み取り・実行のみ

---

### 9. ファイルのパーミッションを設定

```bash
sudo find /var/www/wp.techbull.cloud -type f -exec chmod 644 {} \;

```

- ファイルだけに対して権限 644 を付与
    - 所有者: 読み書き
    - グループ・その他: 読み取りのみ

- **wp-config.phpの修正**

```java
sudo vi /var/www/wp.techbull.cloud/wp-config.php
```

```java
<?php
define('DB_NAME', 'wordpress_db');
define('DB_USER', 'menta');
define('DB_PASSWORD', 'Menta_pw1234');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
```

上記は先ほどMysqlで設定したユーザー名mentaと繋がるように設定する
これは WordPress の **データベース接続情報** を設定するファイル `wp-config.php` の一部です。

順番に説明します。

[このファイルが使用されるタイミング](https://www.notion.so/25e1c69de843808eb469cc9bc78fe3bb?pvs=21)

---

## 1. `DB_NAME`

```php
define( 'DB_NAME', 'wordpress_db' );
```

- **意味**：WordPress が使うデータベース名
- ここでは `wordpress_db` という名前の MySQL データベースに接続することを指しています

---

## 2. `DB_USER`

```php
define( 'DB_USER', 'menta' );

```

- **意味**：データベースに接続するユーザー名
- MySQL 上で作成済みのユーザー `menta` がこの WordPress 用ユーザーです

---

## 3. `DB_PASSWORD`

```php
define( 'DB_PASSWORD', 'Menta_pw1234' );

```

- **意味**：上の `DB_USER` がログインするときのパスワード
- これとユーザー名を使って WordPress はデータベースに接続します

---

## 4. `DB_HOST`

```php
define( 'DB_HOST', 'localhost' );

```

- **意味**：データベースサーバーのホスト名
- `localhost` → 同じサーバー内の MySQL に接続
- 外部サーバーの場合は IP や FQDN に変更します

---

## 5. `DB_CHARSET`

```php
define( 'DB_CHARSET', 'utf8mb4' );

```

- **意味**：WordPress がデータベースで使用する文字コード
- `utf8mb4` → 絵文字や多言語文字を安全に保存可能な推奨文字コード

---

## 6. `DB_COLLATE`

```php
define( 'DB_COLLATE', '' );

```

- **意味**：文字コードの照合順序（ソート順）の指定
- 空文字 `''` → デフォルトの照合順序を使う
- 特にこだわりがなければ空でOK

---
