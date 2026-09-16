import subprocess
import time
import requests
import sys

def run_integration_test():
    print("Starting Python tracker server subprocess...")
    proc = subprocess.Popen(
        [sys.executable, "server.py", "--host", "127.0.0.1", "--port", "8008"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    time.sleep(2.5)

    try:
        base_url = "http://127.0.0.1:8008"
        print("1. Testing GET /health...")
        r = requests.get(f"{base_url}/health", timeout=3)
        assert r.status_code == 200, f"Expected 200, got {r.status_code}"
        health = r.json()
        print("   Health response:", health)
        assert health["status"] == "ok"

        print("2. Testing POST /start...")
        r = requests.post(f"{base_url}/start", timeout=4)
        assert r.status_code == 200
        start_res = r.json()
        print("   Start response:", start_res)
        assert start_res["success"] == True
        assert start_res["is_tracking"] == True

        print("3. Testing GET /status across several frames...")
        for i in range(3):
            time.sleep(0.5)
            r = requests.get(f"{base_url}/status", timeout=2)
            assert r.status_code == 200
            status = r.json()
            print(f"   Status {i+1}: attention={status['attention_percentage']}%, gaze={status['gaze_direction']}, alerts={status['distraction_count']}, alert_needed={status['alert_needed']}")
            assert "attention_percentage" in status
            assert "gaze_direction" in status
            assert "alert_needed" in status

        print("4. Testing POST /reset_alert...")
        r = requests.post(f"{base_url}/reset_alert", timeout=2)
        assert r.status_code == 200

        print("5. Testing POST /stop...")
        r = requests.post(f"{base_url}/stop", timeout=4)
        assert r.status_code == 200
        stop_res = r.json()
        print("   Stop response summary:", stop_res)
        assert "summary" in stop_res
        summary = stop_res["summary"]
        assert "attention_percentage" in summary
        assert "attentive_seconds" in summary
        assert "distraction_count" in summary

        print("\nSUCCESS! All OpenCV attention tracker integration tests passed completely!")

    finally:
        print("Terminating server process...")
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()

if __name__ == "__main__":
    run_integration_test()
