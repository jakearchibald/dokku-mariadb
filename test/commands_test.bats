#!/usr/bin/env bats

load test_helper

setup() {
  mkdir -p "$MARIADB_ROOT"
  echo "fakepass" > "$MARIADB_ROOT/admin_pw"
  dokku apps:create testapp
  # $dokkucmd mariadb:start
}

teardown() {
  # dokku apps:destroy testapp
  rm -rf "$DOKKU_ROOT"
}

@test "mariadb:create requires an app name" {
  run dokku mariadb:create
  assert_exit_status 1
  assert_output "(verify_app_name) APP must not be null"
}

@test "mariadb:create creates files and sets env" {
  run dokku mariadb:create testapp
  assert_db_exists
  assert_success
  assert_output "-----> Creating database testapp
-----> Setting config vars for testapp"
  run dokku config testapp
  assert_contains "$output" "mysql2://testapp"
}

@test "mariadb:delete deletes database" {
  run dokku mariadb:create testapp
  assert_success
  run dokku mariadb:delete testapp
  assert_success
  assert_output "-----> Deleting database testapp
-----> Unsetting config vars for testapp"
  [ ! -f "$MARIADB_ROOT/db_testapp" ]
}

@test "mariadb:list lists databases" {
  run dokku mariadb:create testapp
  run dokku mariadb:list --quiet
  assert_success
  assert_output "exec called with exec -i dokku-mariadbkr sh -c exec mysql -u root -h 127.0.0.1 --password=fakepass"
}

@test "mariadb:url returns mysql url" {
  run dokku mariadb:create testapp
  run dokku mariadb:url testapp
  PASS=$(cat "$MARIADB_ROOT/pass_testapp")
  assert_success
  assert_output "mysql2://testapp:$PASS@mariadb:3306/testapp"
}

@test "mariadb:console calls docker exec" {
  run dokku mariadb:create testapp
  run dokku mariadb:console testapp
  PASS=$(cat "$MARIADB_ROOT/pass_testapp")
  assert_success
  assert_output "exec called with exec --interactive --tty dokku-mariadbkr env TERM=$TERM mysql -h 127.0.0.1 -u testapp --password=$PASS testapp"
}

@test "mariadb:stop stops mysql container" {
  run dokku mariadb:stop
  assert_success
  assert_output "-----> Stopping MariaDB server"
}

@test "mariadb:dump feeds database dump" {
  run dokku mariadb:create testapp
  run dokku mariadb:dump testapp
  assert_success
  assert_output "exec called with exec --interactive --tty dokku-mariadbkr mysqldump -u root --password=fakepass -h 127.0.0.1 testapp"
}

@test "mariadb:docker_args gives correct link" {
  run dokku mariadb:create testapp
  run bash -c "echo 'test' | dokku mariadb:docker_args testapp"
  assert_success
  assert_output "test --link dokku-mariadbkr:mariadb"
}
