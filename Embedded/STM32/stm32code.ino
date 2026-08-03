// Inputs from Raspberry Pi
const int asphaltPin = PA0;
const int gravelPin = PA1;
const int speedPin = PA2;

// PWM Output
const int pwmPin = PA8;

void setup()
{
    pinMode(asphaltPin, INPUT_PULLDOWN);
    pinMode(gravelPin, INPUT_PULLDOWN);
    pinMode(speedPin, INPUT_PULLDOWN);

    pinMode(pwmPin, PWM);

    analogWriteResolution(8);   // 0-255
}

void loop()
{
    bool asphalt = digitalRead(asphaltPin);
    bool gravel = digitalRead(gravelPin);
    bool speed = digitalRead(speedPin);

    if (asphalt)
    {
        // Lowest output
        analogWrite(pwmPin, 0);
    }

    else if (gravel)
    {
        // Medium output (~3 A after calibration)
        analogWrite(pwmPin, 128);
    }

    else if (speed)
    {
        // Maximum output
        analogWrite(pwmPin, 255);
    }

    else
    {
        // No terrain selected
        analogWrite(pwmPin, 0);
    }

    delay(5);
}
