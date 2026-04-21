const SMARTBOX_CODE = {};

SMARTBOX_CODE.desk = `// WORKING CODE FINAL
// Glover, Henry
/* Desk_Control_Module (Remy_The_Robot)
 * Hardware
 * - OLED: SparkFun MicroOLED
 * - RGB LED: Red=A2, Green=MISO, Blue=MOSI
 * - Buzzer: A5
 * - Button: D3
 */

// BLYNK CONFIGURATION
#define BLYNK_TEMPLATE_ID "TMPL23PrbN5Vt"
#define BLYNK_TEMPLATE_NAME "Smart box"
#define BLYNK_AUTH_TOKEN "sCM_hcPtdY65fGc55o8CCniY7hUn6K7-"

#include "Particle.h"
#include "SparkFunMicroOLED.h"
#include <Wire.h>
#include "Pitches.h"
#include <blynk.h>
SerialLogHandler logHandler(LOG_LEVEL_WARN);
SYSTEM_MODE(AUTOMATIC);
SYSTEM_THREAD(ENABLED);

// PIN constants
// OLED
const int OLED_PIN_RESET = D10;
const int OLED_DC_JUMPER = 1;

// RGB LED
const int PIN_LED_RED   = A2;
const int PIN_LED_GREEN = MISO;
const int PIN_LED_BLUE  = MOSI;

// Buzzer and Button
const int PIN_BUZZER = A5;
const int PIN_BUTTON = D3;

// Blynk Virtual Pins (DataStreams)
// V0: Dark Mode (Integer) - 0 = OFF, 1 = ON
// V1: Door Status (String) - OPEN or CLOSED
// V2: Mute (Integer) - 0 = Not Muted, 1 = Muted
// V3: Mail (String) - "PRESENT" or "NONE"
// V4: Mail Time In Box (Integer) - seconds since mail arrived (0 if no mail)
// V5: Mail Counter History (Integer) - total lifetime mail deliveries

// Blynk variables
bool blynkDarkMode = false; // V0
bool blynkMute     = false; // V2
unsigned long lastBlynkUpdate = 0;
const unsigned long blynkUpdateInterval = 2000;

// Mailbox States, from sensor module
enum MailboxState {
  IDLE                  = 0,
  DOOR_OPEN_NO_MAIL     = 1,
  MAIL_PRESENT          = 2,
  MAILBOX_OPEN_TOO_LONG = 3,
  SENSOR_ERROR          = 4
};

// Current Sensor Data
MailboxState currentState = IDLE;

float currentDistance  = -1.0f;
float previousDistance = -1.0f;

bool isDoorOpen       = false;
bool previousDoorOpen = false;

float distanceWhenClosedBeforeOpening = -1.0f;
float distanceWhenClosedAfterOpening  = -1.0f;
float baselineDistance                = -1.0f;

bool motionDetectedDuringCycle = false;
bool mailPresent               = false;
bool previousMailPresent       = false;
bool isPirMotion               = false;

// OLED Pages
const int NUM_PAGES    = 2;
int currentPage        = 0;
bool needDisplayUpdate = true;

// Button Debouncing
int lastButtonState           = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

// Buzzer Timing
bool songActive           = false;
unsigned long songStartTime = 0;
int songNoteIndex         = 0;
bool warningActive        = false;
unsigned long warningStartTime = 0;

// Door timing
time_t doorOpenedAt       = 0;
double lastOpenDuration   = 0;
double totalOpenTime      = 0;

// Counters
uint32_t openCount           = 0;
uint32_t lifetimeMailCounter = 0;

// Mail timestamps
time_t mailArrivalTime = 0;

// Publish rates
unsigned long lastPublishTime         = 0;
const unsigned long publishMinIntervalMs = 1000;
unsigned long lastSignalPublishTime   = 0;
const unsigned long signalPublishIntervalMs = 1000;
int currentSignalIndex  = 0;
const int TOTAL_SIGNALS = 10;
bool publishInProgress  = false;

// Function prototypes
void mailboxEventHandler(const char *event, const char *data);
void handleButton();
void handleRgbLed();
void handleBuzzer();
void triggerNewMailSong();
void playMailSong();
void playWarningSound();
void updateDisplay();
String getStatusString();
void publishTelemetry();
void publishSignal(const char *eventName, const String &value);
void updateBlynk();

// MODE_I2C for OLED
MicroOLED oled(MODE_I2C, OLED_PIN_RESET, OLED_DC_JUMPER);

// ── SETUP ───────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  waitFor(Serial.isConnected, 2000);
  Serial.println("Desk Module (Remy) Starting...");

  pinMode(PIN_LED_RED,   OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_BLUE,  OUTPUT);
  pinMode(PIN_BUZZER,    OUTPUT);
  pinMode(PIN_BUTTON,    INPUT_PULLUP);

  digitalWrite(PIN_LED_RED,   LOW);
  digitalWrite(PIN_LED_GREEN, LOW);
  digitalWrite(PIN_LED_BLUE,  LOW);
  digitalWrite(PIN_BUZZER,    LOW);

  oled.begin();
  oled.clear(ALL);
  oled.display();
  oled.clear(PAGE);

  Particle.subscribe("mailbox_status", mailboxEventHandler, MY_DEVICES);
  Blynk.begin(BLYNK_AUTH_TOKEN);

  Serial.println("Setup Complete. Waiting for events...");
  updateDisplay();
  updateBlynk();
}

// ── MAIN LOOP ───────────────────────────────────────────────
void loop() {
  Blynk.run();
  handleButton();
  handleBuzzer();
  handleRgbLed();
  publishTelemetry();

  unsigned long nowMs = millis();
  if (nowMs - lastBlynkUpdate >= blynkUpdateInterval) {
    updateBlynk();
    lastBlynkUpdate = nowMs;
  }

  static int lastMinute = -1;
  if (Time.minute() != lastMinute) {
    lastMinute = Time.minute();
    needDisplayUpdate = true;
  }
  if (needDisplayUpdate) {
    updateDisplay();
    needDisplayUpdate = false;
  }
}

// ── EVENT HANDLER ───────────────────────────────────────────
// Receives sensor data, detects mail, tracks door, triggers notifications.
// Runs every time there is an update.
//
// Parsing: char buf[64] = string storage (xxx|xxxx|xxxx|xxx)
//   strtok = split string by delimiter (|) into tokens
//   atoi = string -> integer  |  atof = string -> float

void mailboxEventHandler(const char *event, const char *data) {
  if (!data) return;

  String dataStr = String(data);
  Serial.printlnf("Received: %s", dataStr.c_str());

  char buf[64];
  strncpy(buf, dataStr.c_str(), sizeof(buf));
  buf[sizeof(buf) - 1] = 0;

  char *token = strtok(buf, "|");
  if (token) {
    int s = atoi(token);
    if (s < 0 || s > 4) s = 0;
    currentState = (MailboxState)s;
  }

  token = strtok(NULL, "|");
  currentDistance = token ? atof(token) : -1.0f;

  token = strtok(NULL, "|");
  if (token) isDoorOpen = (atoi(token) == 1);

  token = strtok(NULL, "|");
  if (token) isPirMotion = (atoi(token) == 1);

  time_t nowTs = Time.now();

  // Track door opening
  if (!previousDoorOpen && isDoorOpen) {
    doorOpenedAt = nowTs;
    openCount++;
    if (previousDistance >= 0.0f)
      distanceWhenClosedBeforeOpening = previousDistance;
    else if (currentDistance >= 0.0f)
      distanceWhenClosedBeforeOpening = currentDistance;

    if (baselineDistance < 0.0f && distanceWhenClosedBeforeOpening >= 0.0f)
      baselineDistance = distanceWhenClosedBeforeOpening;

    motionDetectedDuringCycle = false;
  }

  if (isDoorOpen && isPirMotion) motionDetectedDuringCycle = true;

  if (previousDoorOpen && !isDoorOpen) {
    distanceWhenClosedAfterOpening = currentDistance;

    if (doorOpenedAt != 0) {
      lastOpenDuration = nowTs - doorOpenedAt;
      totalOpenTime   += lastOpenDuration;
      doorOpenedAt     = 0;
    }

    if (mailPresent) {
      // Mail removed: distance returns to baseline (>= 17.1 cm)
      if (distanceWhenClosedAfterOpening >= 0.0f && distanceWhenClosedAfterOpening >= 17.1f) {
        mailPresent      = false;
        baselineDistance = distanceWhenClosedAfterOpening;
      }
    } else {
      // Check for new mail: motion + open/close + distance < 17.1 cm
      bool mailDetected = (distanceWhenClosedAfterOpening >= 0.0f &&
                           distanceWhenClosedAfterOpening < 17.1f);

      if (motionDetectedDuringCycle && mailDetected) {
        mailPresent = true;
        if (distanceWhenClosedBeforeOpening >= 0.0f)
          baselineDistance = distanceWhenClosedBeforeOpening;
      } else {
        mailPresent = false;
        // Only update baseline if no motion, distance in range, and distance did not decrease
        if (!motionDetectedDuringCycle &&
            distanceWhenClosedAfterOpening >= 0.0f &&
            distanceWhenClosedBeforeOpening >= 0.0f) {
          float delta = distanceWhenClosedAfterOpening - distanceWhenClosedBeforeOpening;
          if (delta >= 0.0f &&
              distanceWhenClosedAfterOpening >= 17.8f &&
              distanceWhenClosedAfterOpening <= 19.8f)
            baselineDistance = distanceWhenClosedAfterOpening;
        }
      }
    }
  }

  if (!previousMailPresent && mailPresent) {
    triggerNewMailSong();
    lifetimeMailCounter++;
    mailArrivalTime = nowTs;
  }

  previousDistance     = currentDistance;
  previousDoorOpen     = isDoorOpen;
  previousMailPresent  = mailPresent;
  needDisplayUpdate    = true;
  publishTelemetry();
}

// ── TELEMETRY (Particle Webhook -> Initial State) ────────────
void publishSignal(const char *eventName, const String &value) {
  if (!Particle.connected()) {
    Serial.printlnf("Not connected - skipping %s", eventName);
    return;
  }
  Serial.printlnf("Publishing %s = %s", eventName, value.c_str());
  if (!Particle.publish(eventName, value, PRIVATE))
    Serial.printlnf("WARNING: Failed to publish %s", eventName);
}

void publishTelemetry() {
  unsigned long nowMs = millis();
  double currentOpenDurationNow = 0;
  if (isDoorOpen && doorOpenedAt != 0)
    currentOpenDurationNow = Time.now() - doorOpenedAt;

  if (!publishInProgress && (nowMs - lastPublishTime >= publishMinIntervalMs)) {
    publishInProgress    = true;
    currentSignalIndex   = 0;
    lastPublishTime      = nowMs;
    lastSignalPublishTime = nowMs;
    Serial.println("Starting telemetry publish cycle...");
  }

  if (publishInProgress && (nowMs - lastSignalPublishTime >= signalPublishIntervalMs)) {
    lastSignalPublishTime = nowMs;
    switch (currentSignalIndex) {
      case 0: publishSignal("Door_Open",            String(isDoorOpen ? 1 : 0)); break;
      case 1: publishSignal("CurrentOpenDuration",  String((int)currentOpenDurationNow)); break;
      case 2: publishSignal("LastOpenDuration",     String((int)lastOpenDuration)); break;
      case 3: publishSignal("TotalOpenTime",        String((int)totalOpenTime)); break;
      case 4: publishSignal("OpenCount",            String(openCount)); break;
      case 5: publishSignal("MailPresent",          String(mailPresent ? 1 : 0)); break;
      case 6: publishSignal("LifeTimeMailCounter",  String(lifetimeMailCounter)); break;
      case 7: publishSignal("MailArrivalTime",      String((long)mailArrivalTime)); break;
      case 8: publishSignal("Distance",             currentDistance >= 0.0f ? String(currentDistance, 1) : "0"); break;
      case 9: publishSignal("BaselineDistance",     baselineDistance >= 0.0f ? String(baselineDistance, 1) : "0"); break;
    }
    if (++currentSignalIndex >= TOTAL_SIGNALS) {
      publishInProgress  = false;
      currentSignalIndex = 0;
      Serial.println("Telemetry publish cycle complete.");
    }
  }
}

// ── HARDWARE CONTROL ─────────────────────────────────────────
void handleButton() {
  int reading = digitalRead(PIN_BUTTON);
  if (reading != lastButtonState) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > debounceDelay) {
    static int buttonState = HIGH;
    if (reading != buttonState) {
      buttonState = reading;
      if (buttonState == LOW) {
        currentPage = (currentPage + 1) % NUM_PAGES;
        needDisplayUpdate = true;
      }
    }
  }
  lastButtonState = reading;
}

void handleRgbLed() {
  if (blynkDarkMode) {
    digitalWrite(PIN_LED_RED,   LOW);
    digitalWrite(PIN_LED_GREEN, LOW);
    digitalWrite(PIN_LED_BLUE,  LOW);
    return;
  }
  bool r = (currentState == MAILBOX_OPEN_TOO_LONG || currentState == SENSOR_ERROR);
  bool g = mailPresent;
  digitalWrite(PIN_LED_RED,   r ? HIGH : LOW);
  digitalWrite(PIN_LED_GREEN, g ? HIGH : LOW);
  digitalWrite(PIN_LED_BLUE,  LOW);
}

void handleBuzzer() {
  if (blynkMute) {
    noTone(PIN_BUZZER);
    songActive = warningActive = false;
    return;
  }
  if (songActive) { playMailSong(); return; }
  if (currentState == MAILBOX_OPEN_TOO_LONG) {
    if (!warningActive) { warningActive = true; warningStartTime = millis(); }
    playWarningSound();
  } else {
    if (warningActive) { warningActive = false; noTone(PIN_BUZZER); }
  }
}

void triggerNewMailSong() {
  songActive = true;
  songStartTime = millis();
  songNoteIndex = 0;
  Serial.println("Song: New Mail!");
}

void playMailSong() {
  // You've Got Mail chime
  int melody[]       = {NOTE_C4, NOTE_E4, NOTE_G4, NOTE_C5, NOTE_G4, NOTE_E4, NOTE_C4};
  int noteDurations[] = {4, 4, 4, 4, 4, 4, 4};
  int numNotes = 7;

  unsigned long elapsed = millis() - songStartTime;
  int totalTime = 0;
  for (int i = 0; i < songNoteIndex && i < numNotes; i++)
    totalTime += 1000 / noteDurations[i];

  if (songNoteIndex < numNotes) {
    int dur   = 1000 / noteDurations[songNoteIndex];
    int start = totalTime;
    int end   = totalTime + dur;
    if      (elapsed >= start && elapsed < end) tone(PIN_BUZZER, melody[songNoteIndex]);
    else if (elapsed >= end)  { noTone(PIN_BUZZER); songNoteIndex++; }
  } else {
    noTone(PIN_BUZZER);
    songActive = false;
  }
}

void playWarningSound() {
  unsigned long cycle = (millis() - warningStartTime) % 600;
  tone(PIN_BUZZER, cycle < 300 ? NOTE_C6 : NOTE_C4);
}

// ── OLED DISPLAY ─────────────────────────────────────────────
String getStatusString() {
  if (mailPresent)                                   return "  MAIL PRESENT";
  if (currentState == MAILBOX_OPEN_TOO_LONG && isDoorOpen) return "  OPEN TOO LONG";
  if (currentState == SENSOR_ERROR)                  return "SENSOR ERROR";
  if (isDoorOpen)                                    return "  BOX OPEN";
  return "  NORMAL";
}

void updateDisplay() {
  oled.clear(PAGE);
  oled.setFontType(0);
  oled.setCursor(0, 0);
  if (currentPage == 0) {
    oled.print("Smart Box");
    oled.setCursor(0, 20);
    oled.print("Status: ");
    oled.print(getStatusString());
  } else {
    oled.print("Smart Box");
    oled.setCursor(0, 8);  oled.print("------");
    oled.setCursor(0, 16); oled.print("Door: "); oled.print(isDoorOpen  ? "OPEN"   : "CLOSED");
    oled.setCursor(0, 24); oled.print("PIR:  "); oled.print(isPirMotion ? "MOTION" : "NO");
    oled.setCursor(0, 32); oled.print("Dist: ");
    if (currentDistance >= 0) { oled.print(currentDistance, 1); oled.print("cm"); }
    else oled.print("N/A");
  }
  oled.display();
}

// ── BLYNK INTEGRATION ────────────────────────────────────────
void updateBlynk() {
  if (!Blynk.connected()) return;
  Blynk.virtualWrite(0, blynkDarkMode ? 1 : 0);        // V0: Dark Mode
  Blynk.virtualWrite(1, isDoorOpen ? "OPEN" : "CLOSED"); // V1: Door Status
  Blynk.virtualWrite(2, blynkMute ? 1 : 0);             // V2: Mute
  Blynk.virtualWrite(3, mailPresent ? "PRESENT" : "NONE"); // V3: Mail

  int mailTimeInBox = 0;
  if (mailPresent && mailArrivalTime > 0)
    mailTimeInBox = (int)(Time.now() - mailArrivalTime);
  Blynk.virtualWrite(4, mailTimeInBox);                 // V4: Mail Time In Box

  Blynk.virtualWrite(5, (int)lifetimeMailCounter);      // V5: Lifetime Mail Count
  Serial.println("Blynk data updated");
}

BLYNK_WRITE(0) { // V0: Dark Mode
  blynkDarkMode = (param.asInt() == 1);
  Serial.printlnf("Blynk Dark Mode: %s", blynkDarkMode ? "ON" : "OFF");
}

BLYNK_WRITE(2) { // V2: Mute
  blynkMute = (param.asInt() == 1);
  Serial.printlnf("Blynk Mute: %s", blynkMute ? "ON" : "OFF");
  if (blynkMute) { noTone(PIN_BUZZER); songActive = warningActive = false; }
}`;

SMARTBOX_CODE.sensor = `#include "Particle.h"
SYSTEM_MODE(AUTOMATIC);
SYSTEM_THREAD(ENABLED);

SerialLogHandler logHandler(LOG_LEVEL_WARN);

/*
 * Final_Sensor Module
 * Sensors:
 *   - Ultrasonic distance sensor  D5 (ECHO) / D6 (TRIGGER)
 *   - PIR Motion sensor           D2
 *   - Magnetic door switch        D4
 *
 * Publishes "mailbox_status" event to Particle Cloud as:
 *   state|distanceCm|doorOpen|pirMotion
 */

// ── PIN DEFINITIONS ──────────────────────────────────────────
const int PIN_ECHO    = D5;
const int PIN_TRIGGER = D6;
const int PIR_PIN     = D2;
const int PIR_LED_PIN = D7;   // Built-in LED indicator
const int MAG_PIN     = D4;   // Magnetic switch: HIGH = open, LOW = closed

// ── CONSTANTS ────────────────────────────────────────────────
const float SPEED_SOUND_CM         = 0.03444; // cm per microsecond
const float CM_TO_IN               = 0.393701;
const float MIN_RANGE_IN           = 1.0;
const float MAX_RANGE_IN           = 157.0;
const float MAIL_PRESENT_THRESHOLD_IN = 8.0;

// ── STATE MACHINE ────────────────────────────────────────────
enum MailboxState {
  IDLE                  = 0,
  DOOR_OPEN_NO_MAIL     = 1,
  MAIL_PRESENT          = 2,
  MAILBOX_OPEN_TOO_LONG = 3,
  SENSOR_ERROR          = 4
};

MailboxState currentState    = IDLE;
bool         lastDoorOpen    = false;
unsigned long doorOpenStartMs = 0;
unsigned long lastPublishMs  = 0;

// ── SETUP ────────────────────────────────────────────────────
void setup() {
  Serial.begin(9600);

  // Ultrasonic
  pinMode(PIN_ECHO,    INPUT);
  pinMode(PIN_TRIGGER, OUTPUT);

  // PIR (LOW = motion)
  pinMode(PIR_PIN,     INPUT_PULLUP);
  pinMode(PIR_LED_PIN, OUTPUT);

  // Magnetic switch (HIGH = open, LOW = closed)
  pinMode(MAG_PIN, INPUT_PULLUP);

  Serial.println("Final_Sensor module starting...");
}

// ── MAIN LOOP ────────────────────────────────────────────────
void loop() {
  // --- Ultrasonic measurement ---
  digitalWrite(PIN_TRIGGER, LOW);
  delayMicroseconds(200);
  digitalWrite(PIN_TRIGGER, HIGH);
  delayMicroseconds(100);
  digitalWrite(PIN_TRIGGER, LOW);

  long sensorTime  = pulseIn(PIN_ECHO, HIGH);
  float distanceCm = sensorTime * SPEED_SOUND_CM / 2.0;
  float distanceIn = distanceCm * CM_TO_IN;

  // --- PIR (LOW = motion detected) ---
  bool pirMotion = (digitalRead(PIR_PIN) == LOW);
  digitalWrite(PIR_LED_PIN, pirMotion ? HIGH : LOW);

  // --- Magnetic switch ---
  bool doorOpen = digitalRead(MAG_PIN); // HIGH = open

  // --- State machine ---
  MailboxState newState = IDLE;

  if (distanceIn <= 0 || distanceIn > MAX_RANGE_IN || sensorTime == 0) {
    newState = SENSOR_ERROR;
  } else {
    bool mailPresent = (distanceIn <= MAIL_PRESENT_THRESHOLD_IN);

    if (doorOpen) {
      if (!lastDoorOpen) doorOpenStartMs = millis();
      unsigned long openDuration = millis() - doorOpenStartMs;

      if      (openDuration > 10000) newState = MAILBOX_OPEN_TOO_LONG;
      else if (mailPresent)          newState = MAIL_PRESENT;
      else                           newState = DOOR_OPEN_NO_MAIL;
    } else {
      newState = mailPresent ? MAIL_PRESENT : IDLE;
    }
  }

  lastDoorOpen = doorOpen;

  // --- Serial debug output ---
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
  Serial.println((int)newState);

  // --- Publish to Particle Cloud (state change OR every 2 s) ---
  unsigned long now = millis();
  if (newState != currentState || (now - lastPublishMs) > 2000) {
    currentState = newState;
    lastPublishMs = now;

    // Packet format: state|distanceCm|doorOpen|pirMotion
    String data = String((int)currentState) + "|" +
                  String(distanceCm, 1)      + "|" +
                  String(doorOpen  ? 1 : 0)  + "|" +
                  String(pirMotion ? 1 : 0);

    bool ok = Particle.publish("mailbox_status", data, PRIVATE);
    Serial.println(String("PUBLISHED mailbox_status: ") + data +
                   (ok ? " [OK]" : " [FAILED]"));
  }

  delay(500);
}`;

// ── TAB SWITCHING ────────────────────────────────────────────
function switchCodeTab(name, btn) {
  document.querySelectorAll('.code-tab').forEach(t => t.classList.remove('active'));
  btn.classList.add('active');
  document.querySelectorAll('.code-panel').forEach(p => p.classList.remove('active'));
  document.getElementById('panel-' + name).classList.add('active');
  document.getElementById('copy-code-btn').dataset.active = name;
}

// ── COPY TO CLIPBOARD ────────────────────────────────────────
function copyCurrentCode() {
  const name = document.getElementById('copy-code-btn').dataset.active || 'desk';
  navigator.clipboard.writeText(SMARTBOX_CODE[name]).then(() => {
    const btn = document.getElementById('copy-code-btn');
    const orig = btn.textContent;
    btn.textContent = 'Copied!';
    setTimeout(() => btn.textContent = orig, 2000);
  });
}

// ── INITIALISE ───────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function () {
  document.getElementById('code-desk').textContent   = SMARTBOX_CODE.desk;
  document.getElementById('code-sensor').textContent = SMARTBOX_CODE.sensor;
  document.getElementById('copy-code-btn').dataset.active = 'desk';
  if (window.Prism) {
    Prism.highlightElement(document.getElementById('code-desk'));
    Prism.highlightElement(document.getElementById('code-sensor'));
  }
});
