#!/usr/bin/env bats

# Start-up and deployment checks. They expect a running container on port
# 8080 named "exist" with build/frus-tei.xar in its autodeploy directory.

@test "container can be reached via http" {
  result=$(curl -Is http://127.0.0.1:8080/ | grep -o 'Jetty')
  [ "$result" == 'Jetty' ]
}

@test "logs show clean start" {
  result=$(docker logs exist 2>&1 | grep -o 'Server has started')
  [ "$result" == 'Server has started' ]
}

@test "logs show package deployment" {
  result=$(docker logs exist 2>&1 | grep -o -m1 'http://history.state.gov/ns/data/frus-tei')
  [ "$result" == 'http://history.state.gov/ns/data/frus-tei' ]
}

@test "a packaged document is stored" {
  status=$(curl -s -o /dev/null -w '%{http_code}' -u admin: \
    http://127.0.0.1:8080/exist/rest/db/apps/frus-tei/data/frus1981-88v05/body/comp/ch1/d1.xml)
  [ "$status" -eq 200 ]
}

@test "its last-modified entry is stored" {
  status=$(curl -s -o /dev/null -w '%{http_code}' -u admin: \
    http://127.0.0.1:8080/exist/rest/db/apps/frus-tei/.last-modified/data/frus1981-88v05/body/comp/ch1/d1.xml)
  [ "$status" -eq 200 ]
}

@test "no fatalities in logs" {
  result=$(docker logs exist 2>&1 | grep -ow -c 'FATAL' || true)
  [ "$result" -eq 0 ]
}
