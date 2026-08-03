import cv2
from ultralytics import YOLO
from picamera2 import Picamera2
import RPi.GPIO as GPIO
from collections import deque, Counter
import time

# ---------------- CONFIG ----------------
CONF_THRESHOLD = 0.50
VOTE_WINDOW = 5

GPIO_ASPHALT = 5
GPIO_GRAVEL = 6
GPIO_SPEEDBUMP = 26

GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

GPIO.setup(GPIO_ASPHALT, GPIO.OUT)
GPIO.setup(GPIO_GRAVEL, GPIO.OUT)
GPIO.setup(GPIO_SPEEDBUMP, GPIO.OUT)


def clear_outputs():
    GPIO.output(GPIO_ASPHALT, GPIO.LOW)
    GPIO.output(GPIO_GRAVEL, GPIO.LOW)
    GPIO.output(GPIO_SPEEDBUMP, GPIO.LOW)


clear_outputs()

# ---------------- MODEL ----------------
model = YOLO("best_ncnn_model", task="classify")

# ---------------- CAMERA ----------------
picam2 = Picamera2()
config = picam2.create_preview_configuration(main={"size": (640, 480)})
picam2.configure(config)
picam2.start()

# ---------------- MAJORITY VOTE ----------------
votes = deque(maxlen=VOTE_WINDOW)

last_output = None


def normalize(name):
    name = name.lower()

    if "asphalt" in name:
        return "ASPHALT"

    if "gravel" in name:
        return "GRAVEL"

    if "speed" in name:
        return "SPEED"

    return None


def set_outputs(terrain):
    clear_outputs()

    if terrain == "ASPHALT":
        GPIO.output(GPIO_ASPHALT, GPIO.HIGH)

    elif terrain == "GRAVEL":
        GPIO.output(GPIO_GRAVEL, GPIO.HIGH)

    elif terrain == "SPEED":
        GPIO.output(GPIO_SPEEDBUMP, GPIO.HIGH)


print("Running...")

try:

    while True:

        frame = picam2.capture_array()
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

        results = model(frame)

        probs = results[0].probs

        if probs is None:
            continue

        class_id = probs.top1
        confidence = probs.top1conf.item()

        raw_name = model.names[class_id]

        print(raw_name, confidence)

        if confidence >= CONF_THRESHOLD:

            terrain = normalize(raw_name)

            if terrain is not None:

                votes.append(terrain)

        if len(votes) == VOTE_WINDOW:

            decision = Counter(votes).most_common(1)[0][0]

            if decision != last_output:

                print("Terrain:", decision)

                set_outputs(decision)

                last_output = decision

        time.sleep(0.03)

except KeyboardInterrupt:
    pass

finally:
    clear_outputs()
    GPIO.cleanup()
    picam2.stop()
