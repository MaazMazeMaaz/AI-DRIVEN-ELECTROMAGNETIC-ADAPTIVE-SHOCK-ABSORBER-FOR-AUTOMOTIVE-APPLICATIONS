import cv2
from ultralytics import YOLO
from picamera2 import Picamera2

# Load your classification model
model = YOLO("best_ncnn_model", task="classify")

# Initialize Pi Camera
picam2 = Picamera2()
config = picam2.create_preview_configuration(main={"size": (640, 480)})
picam2.configure(config)
picam2.start()

print("Running... Press 'q' to quit")

while True:
    # Capture frame
    frame = picam2.capture_array()

    # Convert RGB -> BGR (important for OpenCV)
    frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

    # Optional: resize for speed (uncomment if needed)
    # frame = cv2.resize(frame, (320, 320))

    # Run inference
    results = model(frame)

    probs = results[0].probs
    if probs is not None:
        class_id = probs.top1
        confidence = probs.top1conf.item()
        class_name = model.names[class_id]

        label = f"{class_name} ({confidence:.2f})"
        print(label)

        # Draw result on frame
        cv2.putText(frame, label, (20, 40),
                    cv2.FONT_HERSHEY_SIMPLEX, 1,
                    (0, 255, 0), 2)

    # Show output
    cv2.imshow("Terrain Classification", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cv2.destroyAllWindows()
picam2.stop()
