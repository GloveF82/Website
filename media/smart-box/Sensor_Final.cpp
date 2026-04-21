#include "Particle.h"
SYSTEM_MODE(AUTOMATIC);
SYSTEM_THREAD(ENABLED);

SerialLogHandler logHandler(LOG_LEVEL_WARN);

/*
 Final_Sensor Module
 - Sensors:
    - Ultrasonic
    - PIR Motion sensor --- D2
    - Magnetic switch --- D4
 */

// Ultrasonic Sensor Pins
const int PIN_ECHO = D5;
const int PIN_TRIGGER = D6;

// speed of sound to distance conversion
const float SPEED_SOUND_CM = 0.03444; // speed of sound in cm
const float CM_TO_IN = 0.393701;

const float MIN_RANGE_IN = 1.0;
const float MAX_RANGE_IN = 157.0;
const float WARNING_RANGE_IN = 5.0;

// Threshold for "mail present" in inch
const float MAIL_PRESENT_THRESHOLD_IN = 8.0;

// PIR Sensor Pins
const int PIR_PIN = D2;
const int PIR_LED_PIN = D7; // LED indicator on PHOTON

// Magnetic Switch (D4 → GND)
const int MAG_PIN = D4;

// Mailbox state (Matches Remy_The_Robot Code). At bottom of the code states are made
enum MailboxState
{
  IDLE = 0,
  DOOR_OPEN_NO_MAIL = 1,
  MAIL_PRESENT = 2,
  MAILBOX_OPEN_TOO_LONG = 3,
  SENSOR_ERROR = 4
};

MailboxState currentState = IDLE;
bool lastDoorOpen = false;
unsigned long doorOpenStartMs = 0;
unsigned long lastPublishMs = 0;

void setup()
{
  Serial.begin(9600);
  // ultrasonic
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_TRIGGER, OUTPUT);

  // PIR with pull-up, where LOW = motion
  pinMode(PIR_PIN, INPUT_PULLUP);
  pinMode(PIR_LED_PIN, OUTPUT);

  // Magnetic switch
  pinMode(MAG_PIN, INPUT_PULLUP); // HIGH = open and LOW = closed

  Serial.println("Final_Sensor module starting...");
}

void loop()
{
  // Ultrasonic Trigger
  digitalWrite(PIN_TRIGGER, LOW);
  delayMicroseconds(200);
  digitalWrite(PIN_TRIGGER, HIGH);
  delayMicroseconds(100);
  digitalWrite(PIN_TRIGGER, LOW);

  // ultrasonic Time
  long sensorTime = pulseIn(PIN_ECHO, HIGH);

  // Convert to distance
  float distanceCm = sensorTime * SPEED_SOUND_CM / 2.0;
  float distanceIn = distanceCm * CM_TO_IN;

  // PIR Motion (LOW = motion)
  int alarm = digitalRead(PIR_PIN);
  bool pirMotion = (alarm == LOW);
  digitalWrite(PIR_LED_PIN, pirMotion ? HIGH : LOW);

  // Magnetic Switch
  bool doorOpen = digitalRead(MAG_PIN); // HIGH = open and LOW = closed

  // Mailbox state
  MailboxState newState = IDLE;

  // Error Check
  if (distanceIn <= 0 || distanceIn > MAX_RANGE_IN || sensorTime == 0)
  {
    newState = SENSOR_ERROR;
  }
  else
  {
    // Mail present or not?
    bool mailPresent = (distanceIn <= MAIL_PRESENT_THRESHOLD_IN);

    if (doorOpen)
    {
      // how long the door has been open
      if (!lastDoorOpen)
      {
        doorOpenStartMs = millis();
      }
      unsigned long openDuration = millis() - doorOpenStartMs;

      if (openDuration > 10000) // > 10 seconds
      {
        newState = MAILBOX_OPEN_TOO_LONG;
      }
      else if (mailPresent)
      {
        newState = MAIL_PRESENT;
      }
      else
      {
        newState = DOOR_OPEN_NO_MAIL;
      }
    }
    else
    {
      // Door closed
      if (mailPresent)
      {
        newState = MAIL_PRESENT;
      }
      else
      {
        newState = IDLE;
      }
    }
  }

  lastDoorOpen = doorOpen;

  // SERIAL OUTPUT
  Serial.print("Ultrasonic: ");
  Serial.print(distanceIn, 1);
  Serial.print(" in (");
  Serial.print(distanceCm, 1);
  Serial.print(" cm)");

  Serial.print(" | PIR: ");
  Serial.print(pirMotion ? "MOTION" : "NO MOTION");

  Serial.print(" | Door: ");
  Serial.print(doorOpen ? "OPEN" : "CLOSED");

  Serial.print(" | State: ");
  Serial.print((int)newState);

  Serial.println();

  // Publish to cloud for Remy_The_Robot usign Millis (no disruptions)
  unsigned long now = millis();

  // Only publish when state changes OR every 2 seconds --- can be changed not too much overwhelming data
  if (newState != currentState || (now - lastPublishMs) > 2000)
  {
    currentState = newState;
    lastPublishMs = now;

    // Data stream (state, distance, door, motion)
    String data = String((int)currentState) + "|" + String(distanceCm, 1) + "|" + String(doorOpen ? 1 : 0) + "|" + String(pirMotion ? 1 : 0);

    bool ok = Particle.publish("mailbox_status", data, PRIVATE);
    Serial.println(String("PUBLISHED mailbox_status: ") + data +
                   (ok ? " [OK]" : " [FAILED]"));
  }

  delay(500);
}
