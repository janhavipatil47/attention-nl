# NeuroLearn Frontend

NeuroLearn is a Flutter app. The handwriting screen and the attention screen use
separate local Python services.

## Handwriting Screening

The handwriting screen sends the selected image to the Flask service in the
`NeuroLearn` folder. This service must be running before selecting **Analyze
Handwriting**.

### Windows setup

Open PowerShell in the `NeuroLearn` folder and run:

```powershell
.\run_handwriting_api.bat
```

Keep this terminal open. The service listens on `http://127.0.0.1:8000`.
The model file `handwriting_model.pkl` is beside `api.py` in `NeuroLearn`.
It is already included in the repository. If it is missing, restore the
`khushi_handwriting_model` branch before starting the service.

To install dependencies manually:

```powershell
..\venv\Scripts\python.exe -m pip install -r requirements.txt
```

Check that the service is ready by opening
`http://127.0.0.1:8000/health` in a browser. The response should contain
`"status":"ok"`.

In a second PowerShell window, start Flutter:

```powershell
cd NeuroLearn\frontend
flutter pub get
flutter run -d chrome
```

For Android Emulator, the Flutter code automatically uses
`http://10.0.2.2:8000`. Start `api.py` on the same computer as the emulator.
For a physical phone, replace the API URL with the computer's local network IP
and allow port `8000` through the firewall.

### Handwriting troubleshooting

- `ERR_CONNECTION_REFUSED`: `python api.py` is not running, or it stopped with
	an import/model error.
- `ModuleNotFoundError`: activate the virtual environment and run
	`python -m pip install -r requirements.txt`.
- `handwriting_model.pkl was not found`: run `python train_handwriting.py` from
	the repository root.
- `Not enough handwriting detected`: use a clear, well-lit image containing
	multiple words or letters.

The result is an educational screening aid, not a medical diagnosis.

## ADHD / Attention Tracking

The attention feature is also a local API, but it is a different service. It
uses FastAPI/Uvicorn and OpenCV to read the computer camera. It listens on
`http://127.0.0.1:8008`; it is not the handwriting API and it does not use
port `8000`.

From the `NeuroLearn` folder, start it with either:

```powershell
.\run_attention_tracker.bat
```

or:

```powershell
cd attention_tracker
python server.py --host 127.0.0.1 --port 8008
```

The attention service is needed only when using an activity that records
attention. Handwriting-only use needs `api.py` but does not need the attention
tracker. The computer must have a working camera, and Windows may ask for
camera permission.

Check it with `http://127.0.0.1:8008/health`. The app uses `/start`, `/status`,
`/stop`, `/video_feed`, and the `/ws` WebSocket endpoint during tracking.

## Start everything for a full NeuroLearn run

Use separate terminals:

| Terminal | Location | Command | Required for |
|---|---|---|---|
| 1 | `NeuroLearn` | `run_handwriting_api.bat` | Handwriting screening |
| 2 | `NeuroLearn` | `run_attention_tracker.bat` | Attention tracking |
| 3 | `NeuroLearn\frontend` | `flutter run -d chrome` | Flutter app |

Only terminals for the features being used are required.
