# 개발자용 작업실 구축

## 1. 프로젝트 개요
WSL Ubuntu에서 터미널 기본 조작과 권한 변경을 실습하고,
Docker 커스텀 웹 서버, 포트 매핑, 바인드 마운트 및 볼륨 영속성을 검증했다.
Git으로 소스를 관리하고 VS Code를 GitHub 계정에 연결했다.

## 2. 실행 환경
- 호스트: Windows + WSL2
- OS: Ubuntu 26.04.1 LTS
- Shell: Bash (/bin/bash)
- Git: 2.53.0
- Docker: 29.9.2
- 편집기: VS Code (WSL: Ubuntu)

호스트 Ubuntu와 실습용 ubuntu:24.04 컨테이너는 서로 다른 환경이다.
작업 경로는 ~/dev-workstation이며, 다른 PC에서는 저장소를 복제한 경로를 사용한다.
Docker Desktop 실행 및 해당 Ubuntu 배포판의 WSL Integration 활성화가 필요하다.

## 3. 수행 체크리스트
- [x] 터미널 파일·디렉터리 기본 조작
- [x] 파일과 디렉터리 권한 변경 전후 비교
- [x] Docker 버전 및 데몬 확인
- [x] hello-world 실행
- [x] Ubuntu 컨테이너 내부 명령 실행
- [x] 기본 셸 종료와 exec 셸 종료의 차이 확인
- [x] 이미지·컨테이너 목록, 중지, 로그, 리소스 확인
- [x] Dockerfile 작성 및 커스텀 이미지 빌드
- [x] 포트 매핑과 웹 접속
- [x] 바인드 마운트 변경 반영
- [x] 볼륨 데이터 영속성 확인
- [x] Git 사용자 및 기본 브랜치 설정
- [x] VS Code WSL 연결 및 GitHub 로그인
- [x] GitHub 저장소 업로드 및 증거 이미지 첨부

## 4. 수행 로그 및 증거
입력 명령과 실제 출력은 [터미널 로그](logs/terminal.log)에 기록했다.
로그에는 터미널 색상·제어 문자가 포함될 수 있다.
브라우저 접속 및 VS Code 연동 화면은 아래 11절에 첨부했다.

| 항목 | 검증 방법 | 확인 결과 |
|---|---|---|
| 기본 조작 | pwd, ls -la, mkdir, cd, touch, echo, cat, cp, mv, rm | 파일 생성·복사·이름 변경·삭제 |
| 권한 | chmod, ls -ld | 파일 600→644, 디렉터리 700→755 |
| Docker 점검 | docker --version, docker info | 버전 및 서버 정보 출력 |
| 기본 실행 | docker run hello-world | Hello from Docker! |
| 컨테이너 종료 | bash에서 exit 후 docker ps -a | workstation-ubuntu가 Exited |
| exec 종료 | sleep infinity 컨테이너에 exec 후 exit | 기본 프로세스가 살아 있어 Up 유지 |
| 운영 | docker images, ps -a, logs, stats --no-stream, stop | 목록·로그·리소스·중지 확인 |
| 웹 서버 | docker build, docker run, curl -i | 직접 작성한 HTML 응답 |
| 바인드 마운트 | 호스트 HTML 변경 후 curl | Version 1→Version 2 |
| 볼륨 | 컨테이너 삭제·재생성 후 cat | 동일한 데이터 유지 |

## 5. 커스텀 이미지
공식 nginx:alpine을 베이스로 선택했다.
NGINX의 정적 웹 서버 기능을 활용하고 직접 작성한 HTML로 기본 페이지를 교체했다.

- FROM: 웹 서버 베이스 이미지 선택
- LABEL: 이미지 목적 기록
- COPY: 웹 페이지를 이미지에 포함
- EXPOSE: 컨테이너가 사용하는 80 포트 명시
- EXPOSE만으로 호스트 포트가 공개되지는 않으며 실행 시 -p가 필요하다.

### 빌드와 실행
새 환경에서 아래 명령을 순서대로 실행한다.
동일한 이름의 컨테이너나 포트가 이미 있으면 기존 상태를 확인한 뒤 다른 이름·포트를 사용한다.

```bash
docker build -t bellingham-web:1.0 .
docker run -d --name bellingham-web-8080 \
  -p 127.0.0.1:8080:80 bellingham-web:1.0
curl -i http://localhost:8080
docker logs bellingham-web-8080
```

브라우저 주소: http://localhost:8080

이미지는 빌드 시점의 파일을 복사한다.
저장소의 HTML은 바인드 마운트 실습으로 Version 2로 변경됐으므로,
새로 빌드하면 Version 2가 포함된다. 최초 실습 이미지는 Version 1이었다.

## 6. 바인드 마운트 검증
저장소 루트에서 실행한다.
호스트의 site 디렉터리를 컨테이너의 웹 루트에 읽기 전용으로 연결한다.

```bash
docker run -d --name bellingham-web-8081 \
  -p 127.0.0.1:8081:80 \
  --mount type=bind,source="$(pwd)/site",target=/usr/share/nginx/html,readonly \
  bellingham-web:1.0
curl -s http://localhost:8081
```

실제 실습에서는 아래 명령으로 Version 1을 Version 2로 변경했다.

```bash
sed -i 's/Version 1/Version 2 - bind mount updated/' site/index.html
curl -s http://localhost:8081
```

이미지 재빌드나 컨테이너 재생성 없이 응답이 변경됐다.
재현 시 이미 Version 2이면 해당 문구를 다른 문구로 바꾸어 전후를 비교한다.
브라우저 주소: http://localhost:8081

## 7. 볼륨 영속성 검증
새 환경에서 실행한다. 삭제 대상은 실습용 컨테이너 1개이며 볼륨은 삭제하지 않는다.

```bash
docker volume create bellingham-data
docker run -d --name bellingham-volume-1 \
  --mount source=bellingham-data,target=/data \
  ubuntu:24.04 sleep infinity
docker exec bellingham-volume-1 bash -c \
  'echo "Bellingham persistent data" > /data/message.txt'
docker exec bellingham-volume-1 cat /data/message.txt
docker rm -f bellingham-volume-1
docker run -d --name bellingham-volume-2 \
  --mount source=bellingham-data,target=/data \
  ubuntu:24.04 sleep infinity
docker exec bellingham-volume-2 cat /data/message.txt
```

실제 삭제 전과 새 컨테이너에서 동일한 출력이 확인됐다.

```text
Bellingham persistent data
```

볼륨은 컨테이너와 독립적으로 유지되는 저장소다.
바인드 마운트는 호스트의 지정 경로를 직접 연결한다.

## 8. 핵심 개념
- 절대 경로: /home/bellingham/dev-workstation처럼 루트부터 지정한다.
- 상대 경로: 현재 위치를 기준으로 site/index.html처럼 지정한다.
- 권한 r/w/x의 값은 각각 4/2/1이다.
- 644는 소유자 rw-, 그룹 r--, 기타 r--다.
- 755는 소유자 rwx, 그룹 r-x, 기타 r-x다.
- 디렉터리의 x는 진입·경로 탐색, w는 항목 생성·삭제와 관련된다.
- 포트 매핑은 호스트 포트와 컨테이너 포트를 연결한다.
- exec는 실행 중인 컨테이너에 별도 프로세스를 만든다.
- attach는 기존 기본 프로세스의 입출력에 연결한다. 이번에는 직접 실습하지 않았다.
- Git은 로컬 버전 관리 도구이고 GitHub는 원격 저장소·협업 서비스다.

## 9. 트러블슈팅
### 1) Ubuntu에서 Docker 명령을 찾지 못함
- 문제: docker: command not found
- 원인 가설: Docker Desktop과 WSL Ubuntu의 통합이 비활성화됨
- 확인: Windows에는 Docker Desktop이 있으나 Ubuntu에서 명령 인식 실패
- 해결: Docker Desktop의 Ubuntu WSL Integration을 활성화
- 결과: docker --version에서 29.9.2 확인

### 2) Docker 소켓 접근 권한 거부
- 문제: /var/run/docker.sock 연결 시 permission denied
- 원인 가설: 현재 사용자에게 Docker 소켓 접근 그룹 권한이 적용되지 않음
- 확인: 명령은 인식되지만 docker info와 hello-world 실행 실패
- 해결: sudo usermod -aG docker "$USER" 실행 후 Ubuntu 창을 모두 닫고 다시 실행
- 중간 시도: newgrp docker는 명령이 없어 사용할 수 없었음
- 결과: docker run hello-world 성공
- 주의: docker 그룹은 호스트에 강한 권한을 부여하므로 신뢰하는 사용자에게만 부여한다.

### 3) VS Code에서 Git을 찾지 못함
- 문제: Windows 환경으로 WSL 폴더를 열었을 때 Git not found 표시
- 원인 가설: Ubuntu Git이 아닌 Windows 환경에서 Git을 찾음
- 확인: Ubuntu 터미널에는 Git 2.53.0이 설치되어 있음
- 해결: Microsoft WSL 기능으로 연결 후 과제 폴더를 다시 열음
- 결과: WSL: Ubuntu 표시 및 통합 터미널에서 git status 정상 실행

## 10. Git 설정
커밋 작성자와 기본 브랜치를 다음과 같이 설정했다.

```bash
git config user.name "kangahun1209"
git config user.email "352846497+kangahun1209@users.noreply.github.com"
git config --global init.defaultBranch main
git config --list
```

개인 이메일 대신 GitHub에서 제공하는 noreply 주소를 사용했다.
인증 토큰·비밀번호·개인키는 문서에 기록하지 않는다.

## 11. 화면 증거

### 8080 포트 접속
![8080 포트 웹 페이지](evidence/web-8080.png)

### 8081 포트 및 바인드 마운트 변경 반영
![8081 포트 Version 2](evidence/web-8081.png)

### VS Code GitHub 로그인
![GitHub 계정 연동](evidence/github-vscode.png)

## 12. 실제 재검증 명령과 출력

아래 내용은 재검증 스크립트의 실제 출력이다. +로 시작하는 줄은 실행한 명령이다.

```text
+ echo '=== 현재 위치와 실습 파일 ==='
=== 현재 위치와 실습 파일 ===
+ pwd
/home/bellingham/dev-workstation
+ ls -la practice
total 16
drwxr-xr-x 3 bellingham bellingham 4096 Nov  5 18:54 .
drwxr-xr-x 7 bellingham bellingham 4096 Nov  5 19:30 ..
-rw-r--r-- 1 bellingham bellingham    0 Nov  5 18:53 empty.txt
-rw-r--r-- 1 bellingham bellingham   12 Nov  5 18:53 original.txt
drwxr-xr-x 2 bellingham bellingham 4096 Nov  5 18:54 permission-dir
+ cat practice/original.txt
Hello Linux
+ echo '=== 권한 변경 전 ==='
=== 권한 변경 전 ===
+ chmod 600 practice/original.txt
+ chmod 700 practice/permission-dir
+ ls -ld practice/original.txt practice/permission-dir
-rw------- 1 bellingham bellingham   12 Nov  5 18:53 practice/original.txt
drwx------ 2 bellingham bellingham 4096 Nov  5 18:54 practice/permission-dir
+ echo '=== 권한 변경 후 ==='
=== 권한 변경 후 ===
+ chmod 644 practice/original.txt
+ chmod 755 practice/permission-dir
+ ls -ld practice/original.txt practice/permission-dir
-rw-r--r-- 1 bellingham bellingham   12 Nov  5 18:53 practice/original.txt
drwxr-xr-x 2 bellingham bellingham 4096 Nov  5 18:54 practice/permission-dir
+ echo '=== Docker 버전과 서버 상태 ==='
=== Docker 버전과 서버 상태 ===
+ docker --version
Docker version 29.9.2, build a82e528
+ docker info
Client:
 Version:    29.9.2
 Context:    default
 Debug Mode: false
 Plugins:
  agent: Docker AI Agent Runner (Docker Inc.)
    Version:  v1.152.0
    Path:     /usr/local/lib/docker/cli-plugins/docker-agent
  ai: Docker AI Agent - Ask Gordon (Docker Inc.)
    Version:  v1.33.0
    Path:     /usr/local/lib/docker/cli-plugins/docker-ai
  buildx: Docker Buildx (Docker Inc.)
    Version:  v0.38.1
    Path:     /usr/local/lib/docker/cli-plugins/docker-buildx
  compose: Docker Compose (Docker Inc.)
    Version:  v5.6.1
    Path:     /usr/local/lib/docker/cli-plugins/docker-compose
  debug: Get a shell into any image or container (Docker Inc.)
    Version:  0.49.0
    Path:     /usr/local/lib/docker/cli-plugins/docker-debug
  desktop: Docker Desktop commands (Docker Inc.)
    Version:  4.97.0
    Path:     /usr/local/lib/docker/cli-plugins/docker-desktop
  dhi: CLI for managing Docker Hardened Images (Docker Inc.)
    Version:  v0.0.9
    Path:     /usr/local/lib/docker/cli-plugins/docker-dhi
  extension: Manages Docker extensions (Docker Inc.)
    Version:  v0.2.32
    Path:     /usr/local/lib/docker/cli-plugins/docker-extension
  init: Creates Docker-related starter files for your project (Docker Inc.)
    Version:  v1.4.1
    Path:     /usr/local/lib/docker/cli-plugins/docker-init
  mcp: Docker MCP Plugin (Docker Inc.)
    Version:  v0.44.2
    Path:     /usr/local/lib/docker/cli-plugins/docker-mcp
  model: Docker Model Runner (Docker Inc.)
    Version:  v1.2.9
    Path:     /usr/local/lib/docker/cli-plugins/docker-model
  offload: Docker Offload (Docker Inc.)
    Version:  v0.7.21
    Path:     /usr/local/lib/docker/cli-plugins/docker-offload
  pass: Docker Pass Secrets Manager Plugin (beta) (Docker Inc.)
    Version:  v0.3.2
    Path:     /usr/local/lib/docker/cli-plugins/docker-pass
  sandbox: "docker sandbox" is deprecated, use Docker Sandboxes instead (Docker Inc.)
    Version:  v0.13.0
    Path:     /usr/local/lib/docker/cli-plugins/docker-sandbox
  scout: Docker Scout (Docker Inc.)
    Version:  v1.27.0
    Path:     /usr/local/lib/docker/cli-plugins/docker-scout

Server:
 Containers: 7
  Running: 3
  Paused: 0
  Stopped: 4
 Images: 3
 Server Version: 29.9.2
 Storage Driver: overlayfs
  driver-type: io.containerd.snapshotter.v1
 Logging Driver: local
 Cgroup Driver: cgroupfs
 Cgroup Version: 2
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local splunk syslog
 CDI spec directories:
  /etc/cdi
  /var/run/cdi
 Discovered Devices:
  cdi: docker.com/gpu=webgpu
 Swarm: inactive
 Runtimes: nvidia runc io.containerd.runc.v2
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: b7a25261e029d68978bbf290df0a62fc819b3c51
 runc version: v1.5.2-0-g29dd3dc2
 init version: de40ad0
 Security Options:
  seccomp
   Profile: builtin
  cgroupns
 Kernel Version: 6.18.54.1-microsoft-standard-WSL2
 Operating System: Docker Desktop
 OSType: linux
 Architecture: x86_64
 CPUs: 16
 Total Memory: 15.18GiB
 Name: docker-desktop
 ID: d641a66e-e669-4b4f-bc49-09700b753fc7
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 HTTP Proxy: http.docker.internal:3128
 HTTPS Proxy: http.docker.internal:3128
 No Proxy: hubproxy.docker.internal
 Labels:
  com.docker.desktop.address=unix:///var/run/docker-cli.sock
 Experimental: false
 Insecure Registries:
  hubproxy.docker.internal:5555
  127.0.0.0/8
  ::1/128
 Live Restore Enabled: false
 Firewall Backend: iptables

+ echo '=== hello-world 실행 ==='
=== hello-world 실행 ===
+ docker run --rm hello-world

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

+ echo '=== 이미지와 컨테이너 목록 ==='
=== 이미지와 컨테이너 목록 ===
+ docker images
IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
bellingham-web:1.0   fcc4848da78d       93.6MB         26.3MB   U    
hello-world:latest   c567b231f656       25.9kB         9.49kB   U    
ubuntu:24.04         fe81560990fa        119MB         31.7MB   U    
+ docker ps -a
CONTAINER ID   IMAGE                COMMAND                  CREATED             STATUS                           PORTS                    NAMES
4c6b17c32082   ubuntu:24.04         "sleep infinity"         57 minutes ago      Up 57 minutes                                             bellingham-volume-2
8298fc7e685e   bellingham-web:1.0   "/docker-entrypoint.…"   58 minutes ago      Up 58 minutes                    127.0.0.1:8081->80/tcp   bellingham-web-8081
0f785d9070e8   bellingham-web:1.0   "/docker-entrypoint.…"   59 minutes ago      Up 59 minutes                    127.0.0.1:8080->80/tcp   bellingham-web-8080
19f69d7b68c9   ubuntu:24.04         "sleep infinity"         About an hour ago   Exited (137) About an hour ago                            workstation-running
dc1702efe25e   ubuntu:24.04         "bash"                   About an hour ago   Exited (0) About an hour ago                              workstation-ubuntu
0eaae111ace2   hello-world          "/hello"                 About an hour ago   Exited (0) About an hour ago                              eloquent_mayer
3b4d5b638016   hello-world          "/hello"                 About an hour ago   Exited (0) About an hour ago                              loving_ishizaka
+ echo '=== 웹 서버 로그와 리소스 ==='
=== 웹 서버 로그와 리소스 ===
+ docker logs --tail 15 bellingham-web-8080
2026/11/05 09:58:42 [notice] 1#1: start worker process 38
2026/11/05 09:58:42 [notice] 1#1: start worker process 39
2026/11/05 09:58:42 [notice] 1#1: start worker process 40
2026/11/05 09:58:42 [notice] 1#1: start worker process 41
2026/11/05 09:58:42 [notice] 1#1: start worker process 42
2026/11/05 09:58:42 [notice] 1#1: start worker process 43
2026/11/05 09:58:42 [notice] 1#1: start worker process 44
2026/11/05 09:58:42 [notice] 1#1: start worker process 45
172.17.0.1 - - [05/Nov/2026:09:58:42 +0000] "GET / HTTP/1.1" 200 246 "-" "curl/8.18.0" "-"
172.17.0.1 - - [05/Nov/2026:09:58:52 +0000] "GET / HTTP/1.1" 200 246 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36" "-"
2026/11/05 09:58:52 [error] 32#32: *3 open() "/usr/share/nginx/html/favicon.ico" failed (2: No such file or directory), client: 172.17.0.1, server: localhost, request: "GET /favicon.ico HTTP/1.1", host: "localhost:8080", referrer: "http://localhost:8080/"
172.17.0.1 - - [05/Nov/2026:09:58:52 +0000] "GET /favicon.ico HTTP/1.1" 404 555 "http://localhost:8080/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36" "-"
172.17.0.1 - - [05/Nov/2026:09:58:58 +0000] "GET / HTTP/1.1" 200 246 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36" "-"
2026/11/05 09:58:59 [error] 33#33: *4 open() "/usr/share/nginx/html/favicon.ico" failed (2: No such file or directory), client: 172.17.0.1, server: localhost, request: "GET /favicon.ico HTTP/1.1", host: "localhost:8080", referrer: "http://localhost:8080/"
172.17.0.1 - - [05/Nov/2026:09:58:59 +0000] "GET /favicon.ico HTTP/1.1" 404 555 "http://localhost:8080/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36" "-"
+ docker stats --no-stream bellingham-web-8080
CONTAINER ID   NAME                  CPU %     MEM USAGE / LIMIT    MEM %     NET I/O           BLOCK I/O     PIDS
0f785d9070e8   bellingham-web-8080   0.00%     12.7MiB / 15.18GiB   0.08%     8.44kB / 6.63kB   0B / 12.3kB   17
+ echo '=== 이미지 빌드 ==='
=== 이미지 빌드 ===
+ docker build --progress=plain -t bellingham-web:1.0 .
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 167B done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/nginx:alpine
#2 ...

#3 [auth] library/nginx:pull token for registry-1.docker.io
#3 DONE 0.0s

#2 [internal] load metadata for docker.io/library/nginx:alpine
#2 DONE 1.4s

#4 [internal] load .dockerignore
#4 transferring context: 78B done
#4 DONE 0.0s

#5 [internal] load build context
#5 transferring context: 339B done
#5 DONE 0.0s

#6 [1/2] FROM docker.io/library/nginx:alpine@sha256:785835ea65db4bba6f021acc0f3be91b0fef76a53fe41f8588c6698d2aed0606
#6 resolve docker.io/library/nginx:alpine@sha256:785835ea65db4bba6f021acc0f3be91b0fef76a53fe41f8588c6698d2aed0606 0.0s done
#6 CACHED

#7 [2/2] COPY site/ /usr/share/nginx/html/
#7 DONE 0.0s

#8 exporting to image
#8 exporting layers 0.1s done
#8 exporting manifest sha256:34a006186a0dfacde5e0f0cc8ee5e893002897b6c215f75f3196a31c2e6e5b50 0.0s done
#8 exporting config sha256:4868ce1b57853119fff4f4cfd3d7c108fd106d3a75c562504b2ebe76b5236b20 done
#8 exporting attestation manifest sha256:bb1a274b5db23e16d42eb16da6ec34d1f2c1626189bb3f0c639b8a6f7a19fcf2 0.0s done
#8 exporting manifest list sha256:443af74d7f20c3744ebc16ab7fb92d54614e0bc043c7c1a1f80f433c121e370c 0.0s done
#8 naming to docker.io/library/bellingham-web:1.0 done
#8 unpacking to docker.io/library/bellingham-web:1.0 0.0s done
#8 DONE 0.1s
+ echo '=== 포트별 실제 HTTP 응답 ==='
=== 포트별 실제 HTTP 응답 ===
+ curl --fail --retry 5 --retry-connrefused -i http://localhost:8080
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
  0      0   0      0   0      0      0      0                              0100    246 100    246   0      0  27430      0                              0100    246 100    246   0      0  26814      0                              0100    246 100    246   0      0  26301      0                              0
HTTP/1.1 200 OK
Server: nginx/1.31.8
Date: Thu, 05 Nov 2026 10:57:48 GMT
Content-Type: text/html
Content-Length: 246
Last-Modified: Thu, 05 Nov 2026 09:58:01 GMT
Connection: keep-alive
ETag: "6aec5329-f6"
Accept-Ranges: bytes

<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>Bellingham Dev Workstation</title>
</head>
<body>
  <h1>Bellingham Dev Workstation</h1>
  <p>My custom Docker web server is running.</p>
  <p>Version 1</p>
</body>
</html>
+ curl --fail --retry 5 --retry-connrefused -i http://localhost:8081
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
  0      0   0      0   0      0      0      0                              0100    267 100    267   0      0  70467      0                              0100    267 100    267   0      0  66220      0                              0100    267 100    267   0      0  63225      0                              0
HTTP/1.1 200 OK
Server: nginx/1.31.8
Date: Thu, 05 Nov 2026 10:57:48 GMT
Content-Type: text/html
Content-Length: 267
Last-Modified: Thu, 05 Nov 2026 09:59:34 GMT
Connection: keep-alive
ETag: "6aec5386-10b"
Accept-Ranges: bytes

<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>Bellingham Dev Workstation</title>
</head>
<body>
  <h1>Bellingham Dev Workstation</h1>
  <p>My custom Docker web server is running.</p>
  <p>Version 2 - bind mount updated</p>
</body>
</html>
+ echo '=== 바인드 마운트 변경 전 ==='
=== 바인드 마운트 변경 전 ===
+ curl --fail -s http://localhost:8081
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>Bellingham Dev Workstation</title>
</head>
<body>
  <h1>Bellingham Dev Workstation</h1>
  <p>My custom Docker web server is running.</p>
  <p>Version 2 - bind mount updated</p>
</body>
</html>
+ sed -i 's/Version 2 - bind mount updated/Version 3 - live verification/' site/index.html
+ echo '=== 바인드 마운트 변경 후 ==='
=== 바인드 마운트 변경 후 ===
+ curl --fail -s http://localhost:8081
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>Bellingham Dev Workstation</title>
</head>
<body>
  <h1>Bellingham Dev Workstation</h1>
  <p>My custom Docker web server is running.</p>
  <p>Version 3 - live verification</p>
</body>
</html>
+ sed -i 's/Version 3 - live verification/Version 2 - bind mount updated/' site/index.html
+ echo '=== 기존 볼륨과 데이터 확인 ==='
=== 기존 볼륨과 데이터 확인 ===
+ docker volume inspect bellingham-data
[
    {
        "CreatedAt": "2026-11-05T10:00:30Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/bellingham-data/_data",
        "Name": "bellingham-data",
        "Options": null,
        "Scope": "local"
    }
]
+ docker exec bellingham-volume-2 cat /data/message.txt
Bellingham persistent data
+ echo '=== 임시 컨테이너에서 데이터 확인 ==='
=== 임시 컨테이너에서 데이터 확인 ===
++ date +%s
+ volume_check=volume-check-1793876268-11507
+ docker run -d --name volume-check-1793876268-11507 --mount source=bellingham-data,target=/data ubuntu:24.04 sleep infinity
1e76c20d548735436677d75854ec4ea56208a3dc3b36fd8c9cb18dc7639a72ad
+ docker exec volume-check-1793876268-11507 cat /data/message.txt
Bellingham persistent data
+ echo '=== 임시 컨테이너 삭제 ==='
=== 임시 컨테이너 삭제 ===
+ docker rm -f volume-check-1793876268-11507
volume-check-1793876268-11507
+ echo '=== 새 컨테이너에서도 데이터 유지 확인 ==='
=== 새 컨테이너에서도 데이터 유지 확인 ===
+ docker run -d --name volume-check-1793876268-11507-new --mount source=bellingham-data,target=/data ubuntu:24.04 sleep infinity
e352bb371a50811f7b062901ca276b6c8264781a513e57b2d56f3978dd5e15a1
+ docker exec volume-check-1793876268-11507-new cat /data/message.txt
Bellingham persistent data
+ docker rm -f volume-check-1793876268-11507-new
volume-check-1793876268-11507-new
+ echo '=== Git 설정과 원격 저장소 ==='
=== Git 설정과 원격 저장소 ===
+ git config --list
init.defaultbranch=main
core.repositoryformatversion=0
core.filemode=true
core.bare=false
core.logallrefupdates=true
user.name=kangahun1209
user.email=352846497+kangahun1209@users.noreply.github.com
remote.origin.url=https://github.com/kangahun1209/dev-workstation.git
remote.origin.fetch=+refs/heads/*:refs/remotes/origin/*
branch.main.remote=origin
branch.main.merge=refs/heads/main
+ git remote -v
origin	https://github.com/kangahun1209/dev-workstation.git (fetch)
origin	https://github.com/kangahun1209/dev-workstation.git (push)
+ git log -3 --oneline
72c5019 Blur unrelated details in evidence screenshots
c6fe78d Mark GitHub publication and evidence complete
4d9b8fe Document development workstation setup and verification
+ echo '=== 프로젝트 파일 구조 ==='
=== 프로젝트 파일 구조 ===
+ find . -maxdepth 2 -not -path './.git*' -not -path './.git/*'
+ sort
.
./.dockerignore
./Dockerfile
./README.md
./evidence
./evidence/github-vscode.png
./evidence/web-8080.png
./evidence/web-8081.png
./logs
./logs/terminal.log
./logs/verification.log
./practice
./practice/empty.txt
./practice/original.txt
./practice/permission-dir
./site
./site/index.html

```

## 13. 컨테이너 네트워크와 포트 매핑

컨테이너는 별도의 네트워크 네임스페이스를 사용하므로 호스트와
네트워크 인터페이스·포트 공간이 분리된다.
컨테이너 안의 localhost는 해당 컨테이너 자신을 가리킨다.

이번 실행의 포트 설정은 다음과 같다.

```text
127.0.0.1:8080:80
호스트 주소 : 호스트 포트 : 컨테이너 포트
```

브라우저가 호스트의 8080 포트로 요청하면 Docker가 설정한
포트 전달 경로를 통해 컨테이너의 80 포트에서 실행 중인 NGINX로 전달된다.
Docker Desktop과 WSL 환경에서는 이 과정에 가상 머신의 네트워크도 관여한다.
127.0.0.1로 바인딩하여 로컬 접속용으로 설정했다.

### 포트 충돌 진단과 해결

아래는 충돌 발생 시 사용할 진단 절차이며, 실제 충돌을 재현한 로그는 아니다.

```bash
# Docker 컨테이너가 사용 중인 포트 확인
docker ps --format 'table {{.Names}}\t{{.Ports}}'

# Ubuntu에서 보이는 수신 포트 확인
ss -ltnp 'sport = :8080'
```

Docker Desktop에서는 Windows 쪽 프로그램이 포트를 사용할 수도 있다.
그 경우 Windows PowerShell에서 확인한다.

```powershell
Get-NetTCPConnection -LocalPort 8080 -State Listen
```

사용 중인 컨테이너가 이번 실습용임을 확인했고 종료해도 된다면
해당 컨테이너를 docker stop으로 중지한다.
다른 프로그램의 포트라면 임의로 종료하지 않고 다른 호스트 포트를 선택한다.

```bash
# 대체 포트 사용 예시
docker run -d --name bellingham-web-8082 \
  -p 127.0.0.1:8082:80 bellingham-web:1.0
```

## 14. 이미지와 경로 선택

이미지는 빌드 시점의 파일을 포함하는 실행 템플릿이고,
컨테이너는 그 이미지로 만든 실행 인스턴스다.
호스트 파일을 수정해도 COPY로 만든 기존 이미지와 컨테이너의 파일은
자동으로 바뀌지 않는다. 반면 바인드 마운트는 연결한 호스트 파일의 변경을 반영한다.

호스트에서 편집할 소스는 프로젝트의 site/에 두고,
컨테이너 내부에서는 NGINX의 웹 루트인 /usr/share/nginx/html/을 사용했다.
실행 명령의 $(pwd)는 현재 프로젝트 위치를 절대 경로로 바꾸므로,
다른 PC에서도 저장소 루트에서 실행하면 해당 PC의 경로를 사용할 수 있다.
