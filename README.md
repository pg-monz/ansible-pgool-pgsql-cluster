pg_monz 2.0 テスト環境用 Playbook
===============================
本 Playbook は pg_monz 2.0 で監視対象とする pgpool-II + PostgreSQL クラスタを構築します。

Ansible のインストール
----------------------
公式サイトのドキュメント ([Installation](http://docs.ansible.com/intro_installation.html#installation)) をご参照ください。Ansible 側の設定は特に必要なく、インストールさえ完了すればすぐに Playbook は実行可能です。

Playbook の設定
--------------------------
主に設定が必要なパラメータは以下の通りです。それ以外はデフォルトでも問題ありません。

### group_vars/all.yml

| パラメータ                | 設定値                  | 説明                                                             |
|:--------------------------|:------------------------|------------------------------------------------------------------|
| pg_ver                    | 92 or 93 or 94          | PostgreSQL のメジャーバージョン                                  |
| repli_mode                | stream or native        | pgpool-II のレプリケーションモード                               |
| synchronous_standby_names | 'standby1,standby2,...' | synchronous_standby_names@postgresql.conf に指定する文字列(\*)   |
| pgport                    | 5432                    | PostgreSQL の待ち受けポート（全サーバ共通）                      |
| vip                       | 192.168.1.101           | pgpool-II で利用する仮想 IP                                      |
| pgpool_active_ip          | pgpool01                | デプロイ時に Active になる pgpool-II IP アドレス or ホスト名     |
| pgpool_standby_ip         | pgpool02                | デプロイ時に Standby になる pgpool-II IP アドレス or ホスト名    |
| pgsql_primary_ip          | pgsql01                 | デプロイ時に Primary になる バックエンド IP アドレス or ホスト名 |
| pgsql_standby01_ip        | pgsql02                 | デプロイ時に standby になる バックエンド IP アドレス or ホスト名 |
| pgsql_standby02_ip        | pgsql03                 | デプロイ時に standby になる バックエンド IP アドレス or ホスト名 |
| nic                       | eth1                    | vip に使うデバイス名                                             |

### ./hosts
デプロイ対象となるサーバに対して Ansible が使う接続パラメータです。スペース区切りで以下の通り指定してください。

```
<ホスト名> <SSH 接続する sudo 権限を持ったユーザ> <デプロイ先 IP> <（あれば）SSH 接続用秘密鍵>
```

その他、デプロイ対象をグルーピングしたりしていますが、特に編集する必要はありません。

```cfg:hosts
:
:
[pgsql_standby]
pgsql02 ansible_ssh_user=vagrant ansible_ssh_host=192.168.1.22 ansible_ssh_private_key_file=/home/masano/.vagrant.d/insecure_private_key
pgsql03 ansible_ssh_user=vagrant ansible_ssh_host=192.168.1.23 ansible_ssh_private_key_file=/home/masano/.vagrant.d/insecure_private_key
# pgsql02 ansible_ssh_user=root ansible_ssh_host=133.137.176.146
# pgsql03 ansible_ssh_user=root ansible_ssh_host=133.137.176.147

[pgsql:children]
pgsql_primary
pgsql_standby
```

Ansible の実行
--------------
all.yml と hosts の設定が完了したら、以下のコマンドでデプロイが開始されます。

```sh
masano@SRAOSS-CF-SX2:Ansible$ pwd
/home/masano/work/pg_monz_2.0/Ansible
masano@SRAOSS-CF-SX2:Ansible$ ls
README.md  clean_up.yml  group_vars  hosts  install.yml  prepare.yml  put_files.yml  roles  site.yml  start_all.yml  temp
masano@SRAOSS-CF-SX2:Ansible$ ansible-playbook -i hosts site.yml
```

SSH 接続時、sudo 実行時にパスワードの入力が必要な場合は以下のオプションを指定します。`ansible-playbook`  実行時に対話形式でパスワードの入力を求められます。

```sh
masano@SRAOSS-CF-SX2:Ansible$ ansible-playbook --ask-pass --ask-sudo-pass -i hosts site.yml
SSH password: 
sudo password [defaults to SSH password]: 
:
:
```

Playbook の実行概要
-------------------
本プレイブックで実行される処理内容は、おおまかには以下の通りです。

* site.yml
  以下のファイルを呼び出す。
  * ./clean_up.yml
    * Ansible でインストールした pgpool-II、PostgreSQL、ソケットファイル、pid ファイル、データベースクラスタなどを削除します。
  * ./prepare.yml
    * デプロイ対象のサーバの root、PostgreSQL ユーザがそれぞれのサーバに公開鍵認証で SSH できるように SSH 鍵ペア、config ファイル、authorized_keys を配置します。
    * pgdg rpm、pgpool-II のソースディレクトリを各サーバに配置します。
  * ./install.yml
    * pgpool-II をソースからビルドし、PostgreSQL を コミュニティリポジトリから YUM でインストールします。
  * ./put_files.yml
    * pgpool-II、PostgreSQL の各種設定ファイル、スクリプトを配置します。
  * ./start_all.yml
    * pgpool-II、PostgreSQL を起動し、オンラインリカバリを使ってスタンバイサーバを構築します。
