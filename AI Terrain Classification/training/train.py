from google.colab import drive
import zipfile
import os
# Mount Google Drive
drive.mount('/content/drive')
# Install Ultralytics
!pip install ultralytics
----
zip_path = '/content/drive/MyDrive/Tdata.zip' 
extract_path = '/content/Tdata'
# 1. Unzip dataset
with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    zip_ref.extractall(extract_path)
# 2. Fix nested directory if Tdata/Tdata exists
nested_path = os.path.join(extract_path, 'Tdata')
if os.path.exists(nested_path):
    !mv /content/Tdata/Tdata/* /content/Tdata/
    !rmdir /content/Tdata/Tdata
# 3. Verify folders (should output: train val or train test)
print("Folder contents:")
!ls /content/Tdata
----
from ultralytics import YOLO
# Load pretrained YOLOv8 Nano classification model
model = YOLO('yolov8n-cls.pt')
# Train model
results = model.train(
    data='/content/Tdata', 
    epochs=50, 
    imgsz=224, 
    batch=16,
    project='/content/drive/MyDrive/YOLO_Results', 
    name='terrain_classifier'
)
----
from google.colab import files
best_weights = '/content/drive/MyDrive/YOLO_Results/terrain_classifier/weights/best.pt'
if os.path.exists(best_weights):
    print("Found trained model! Triggering download...")
    files.download(best_weights)
else:
    print("Could not find best.pt. Check the YOLO_Results folder in your Google Drive.")
----
