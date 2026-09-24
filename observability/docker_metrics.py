import json
import socket
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, HTTPServer

SOCKET_PATH = "/var/run/docker.sock"
PORT = 9100


def docker_get(path):
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(SOCKET_PATH)
    client.sendall(
        f"GET {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".encode()
    )
    chunks = []
    while True:
        chunk = client.recv(65536)
        if not chunk:
            break
        chunks.append(chunk)
    client.close()
    response = b"".join(chunks)
    headers, payload = response.split(b"\r\n\r\n", 1)
    if b"transfer-encoding: chunked" in headers.lower():
        decoded = bytearray()
        while payload:
            size_end = payload.find(b"\r\n")
            size = int(payload[:size_end], 16)
            if size == 0:
                break
            start = size_end + 2
            decoded.extend(payload[start : start + size])
            payload = payload[start + size + 2 :]
        payload = bytes(decoded)
    return json.loads(payload)


def labels(container):
    service = container.get("Labels", {}).get("com.docker.compose.service", "")
    return service if service.startswith("server-") else None


def metric(name, help_text, metric_type, samples):
    lines = [f"# HELP {name} {help_text}", f"# TYPE {name} {metric_type}"]
    for service, value in samples:
        lines.append(
            f'{name}{{container_label_com_docker_compose_service="{service}"}} {value}'
        )
    return "\n".join(lines)


def collect():
    cpu = []
    memory = []
    transmit = []
    receive = []
    containers = [
        container
        for container in docker_get("/containers/json")
        if labels(container) is not None
    ]

    def read_stats(container):
        return labels(container), docker_get(
            f"/containers/{container['Id']}/stats?stream=false"
        )

    with ThreadPoolExecutor(max_workers=4) as executor:
        container_stats = executor.map(read_stats, containers)

    for service, stats in container_stats:
        cpu.append((service, stats["cpu_stats"]["cpu_usage"]["total_usage"] / 1_000_000_000))
        memory.append((service, stats["memory_stats"]["usage"]))
        tx = 0
        rx = 0
        for network in stats.get("networks", {}).values():
            tx += network.get("tx_bytes", 0)
            rx += network.get("rx_bytes", 0)
        transmit.append((service, tx))
        receive.append((service, rx))

    return "\n\n".join(
        [
            metric("docker_container_cpu_usage_seconds_total", "Container CPU usage in seconds", "counter", cpu),
            metric("docker_container_memory_usage_bytes", "Container memory usage in bytes", "gauge", memory),
            metric("docker_container_network_transmit_bytes_total", "Container transmitted bytes", "counter", transmit),
            metric("docker_container_network_receive_bytes_total", "Container received bytes", "counter", receive),
        ]
    ) + "\n"


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return
        body = collect().encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


HTTPServer(("0.0.0.0", PORT), MetricsHandler).serve_forever()
