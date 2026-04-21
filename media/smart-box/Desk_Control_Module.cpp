// WORKING CODE FINAL
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
const int PIN_LED_RED = A2;
const int PIN_LED_GREEN = MISO;
const int PIN_LED_BLUE = MOSI;

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
bool blynkMute = false;     // V2
unsigned long lastBlynkUpdate = 0;
const unsigned long blynkUpdateInterval = 2000;

// Mailbox States, from sensor module
enum MailboxState
{
  IDLE = 0,
  DOOR_OPEN_NO_MAIL = 1,
  MAIL_PRESENT = 2,
  MAILBOX_OPEN_TOO_LONG = 3,
  SENSOR_ERROR = 4
};

// Current Sensor Data
MailboxState currentState = IDLE;

// float = decmial values (f = float)--------1.0 b/c no value or unknown
float currentDistance = -1.0f;
float previousDistance = -1.0f; // To detect distance change if mail is in box

// bool is only true or false
bool isDoorOpen = false;
bool previousDoorOpen = false; // To detect door opening/closing

float distanceWhenClosedBeforeOpening = -1.0f;
float distanceWhenClosedAfterOpening = -1.0f;

float baselineDistance = -1.0f; // Baseline distance when mailbox is empty (no mail)

bool motionDetectedDuringCycle = false; // Track if motion was detected during open/close cycle
bool mailPresent = false;               // Track if mail is currently present
bool previousMailPresent = false;       // To detect mail present transitions

bool isPirMotion = false;

// OLED Pages
const int NUM_PAGES = 2;
int currentPage = 0;
bool needDisplayUpdate = true;

// Button Debouncing
int lastButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

// Buzzer Timing Variables
bool songActive = false;         // True when playing the "New Mail" song
unsigned long songStartTime = 0; // When the song started
int songNoteIndex = 0;           // Current note index in the song
bool warningActive = false;      // True when playing warning sound
unsigned long warningStartTime = 0;

// Initial State DASHBOARD

// Door timing - Time.now() or time_t "number of seconds since"
time_t doorOpenedAt = 0;
double lastOpenDuration = 0; // seconds (last completed open cycle)
double totalOpenTime = 0;    // cumulative seconds mailbox was open

// Counters (ensures they're non-negative and can grow large)
uint32_t openCount = 0;           // number of times mailbox was opened
uint32_t lifetimeMailCounter = 0; // total mail deliveries

// Mail timestamps
time_t mailArrivalTime = 0;

// Publish rates
unsigned long lastPublishTime = 0;
const unsigned long publishMinIntervalMs = 1000;
unsigned long lastSignalPublishTime = 0;
const unsigned long signalPublishIntervalMs = 1000;
int currentSignalIndex = 0;
const int TOTAL_SIGNALS = 10;
bool publishInProgress = false;

// Functions
void mailboxEventHandler(const char *event, const char *data);
void handleButton();
void handleRgbLed();
void handleBuzzer();
void triggerNewMailSong();
void playMailSong();
void playWarningSound();
void updateDisplay();
String getStatusString();

// publisher for Initial State
void publishTelemetry();
void publishSignal(const char *eventName, const String &value);

// Blynk functions
void updateBlynk();

// MODE_I2C for OLED
MicroOLED oled(MODE_I2C, OLED_PIN_RESET, OLED_DC_JUMPER);

// Setup
void setup()
{
  // System setup
  Serial.begin(115200);
  waitFor(Serial.isConnected, 2000);
  Serial.println("Desk Module (Remy) Starting...");

  // Pin Modes
  pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_BLUE, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);

  // Initial Output States
  digitalWrite(PIN_LED_RED, LOW);
  digitalWrite(PIN_LED_GREEN, LOW);
  digitalWrite(PIN_LED_BLUE, LOW);
  digitalWrite(PIN_BUZZER, LOW);

  // Initialize OLED
  oled.begin();
  oled.clear(ALL);
  oled.display();
  oled.clear(PAGE);

  // Subscribe to the sensor module's events
  Particle.subscribe("mailbox_status", mailboxEventHandler, MY_DEVICES);

  // Initialize Blynk
  Blynk.begin(BLYNK_AUTH_TOKEN);

  Serial.println("Setup Complete. Waiting for events...");

  // Draw initial screen
  updateDisplay();

  // Initial Blynk update
  updateBlynk();
}

// MAIN LOOP
void loop()
{
  Blynk.run();

  handleButton();
  handleBuzzer();
  handleRgbLed();

  publishTelemetry();

  // Update Blynk
  unsigned long nowMs = millis();
  if (nowMs - lastBlynkUpdate >= blynkUpdateInterval)
  {
    updateBlynk();
    lastBlynkUpdate = nowMs;
  }

  // update display
  static int lastMinute = -1;
  if (Time.minute() != lastMinute)
  {
    lastMinute = Time.minute();
    needDisplayUpdate = true;
  }

  if (needDisplayUpdate)
  {
    updateDisplay();
    needDisplayUpdate = false;
  }
}

// Event (Core function) Recives senor data, detects mial, tracks door, trigger notifactions,
// runs everytime ther is an update

// PARSING STRINGS for data
// char buf[64] = string storage (64 chars) (xxx|xxxx|xxxx|xxx)
// sizeof(buf) = size(64) = 64 bites
// strtok = split string by delimiter (| ---> this is dilimiter) into tokens
// atoi = string → integer
// atof = string → float
// strncpy = safe string copy with a length limit

void mailboxEventHandler(const char *event, const char *data)
{
  if (!data) // does data exist?
    return;

  String dataStr = String(data); // converts to string and shows whats recieved in serial monitor
  Serial.printlnf("Received: %s", dataStr.c_str());

  // Parse Data splits it using dlimiter (|)- (state,distanceCm,doorOpen,pirMotion)
  char buf[64];
  strncpy(buf, dataStr.c_str(), sizeof(buf)); // dataStr = String object, .c_str() = converts String → char* (C-style string)
  buf[sizeof(buf) - 1] = 0;

  char *token = strtok(buf, "|");
  if (token)
  {
    int s = atoi(token);
    if (s < 0 || s > 4)
      s = 0;
    currentState = (MailboxState)s; // converts to int → stores in currentState
  }

  token = strtok(NULL, "|");
  if (token)
    currentDistance = atof(token); // converts to float → stores in currentDistance
  else
    currentDistance = -1.0f;

  token = strtok(NULL, "|");
  if (token)
    isDoorOpen = (atoi(token) == 1); // converts to int → stores in isDoorOpen

  token = strtok(NULL, "|");
  if (token)
    isPirMotion = (atoi(token) == 1); // converts to int → stores in isPirMotion

  time_t nowTs = Time.now();

  // Track door opening
  if (!previousDoorOpen && isDoorOpen)
  {
    doorOpenedAt = nowTs;
    openCount++;

    // Door just opened - save distance when it was closed for PIR
    if (previousDistance >= 0.0f)
    {
      distanceWhenClosedBeforeOpening = previousDistance;
    }
    else if (currentDistance >= 0.0f)
    {
      distanceWhenClosedBeforeOpening = currentDistance;
    }

    // set basline if not done
    if (baselineDistance < 0.0f && distanceWhenClosedBeforeOpening >= 0.0f)
    {
      baselineDistance = distanceWhenClosedBeforeOpening;
    }

    // Reset tracking
    motionDetectedDuringCycle = false;
  }

  // Track motion + door open cycle
  if (isDoorOpen && isPirMotion)
  {
    motionDetectedDuringCycle = true;
  }

  if (previousDoorOpen && !isDoorOpen)
  {
    distanceWhenClosedAfterOpening = currentDistance;

    if (doorOpenedAt != 0)
    {
      lastOpenDuration = nowTs - doorOpenedAt;
      totalOpenTime += lastOpenDuration;
      doorOpenedAt = 0;
    }

    // If mail was already present, check for removal (distance returns to baseline)
    if (mailPresent)
    {
      // Mail removed when distance >= 17.1cm (back to normal range)
      // Baseline is 18.8cm ±1cm (17.8-19.8cm), so >= 17.1cm = no mail
      if (distanceWhenClosedAfterOpening >= 0.0f && distanceWhenClosedAfterOpening >= 17.1f)
      {
        mailPresent = false;
        baselineDistance = distanceWhenClosedAfterOpening;
      }
    }
    else
    {
      // If no mail was present, check if new mail was added
      // Mail is detected when distance < 17.1cm (mail blocks sensor from bottom)
      // Baseline is 18.8cm ±1cm (17.8-19.8cm), so < 17.1cm = mail present
      bool mailDetected = false;
      if (distanceWhenClosedAfterOpening >= 0.0f)
      {
        mailDetected = (distanceWhenClosedAfterOpening < 17.1f);
      }

      // Mail present when -----> motion + open/close + distance < 17.1cm
      if (motionDetectedDuringCycle && mailDetected)
      {
        mailPresent = true;

        if (distanceWhenClosedBeforeOpening >= 0.0f)
        {
          baselineDistance = distanceWhenClosedBeforeOpening;
        }
      }
      else
      {
        // No mail detected
        mailPresent = false;

        // Only update baseline if:
        // 1. No motion was detected (confident no mail was added)
        // 2. Distance is in baseline range (17.8-19.8cm, since baseline is 18.8cm +-1cm)
        // 3. Distance INCREASED or stayed the same (never update baseline if distance decreased - that suggests mail)
        if (!motionDetectedDuringCycle && distanceWhenClosedAfterOpening >= 0.0f &&
            distanceWhenClosedBeforeOpening >= 0.0f)
        {
          // Only update if distance increased or stayed same (not decreased)
          float distanceChange = distanceWhenClosedAfterOpening - distanceWhenClosedBeforeOpening;
          if (distanceChange >= 0.0f && // Distance increased or stayed same
              distanceWhenClosedAfterOpening >= 17.8f &&
              distanceWhenClosedAfterOpening <= 19.8f)
          {
            baselineDistance = distanceWhenClosedAfterOpening;
          }
        }
        // If distance decreased but no motion detected, don't update baseline
        // (could be mail present but motion sensor missed it)
      }
    }
  }

  if (!previousMailPresent && mailPresent)
  {
    triggerNewMailSong();
    lifetimeMailCounter++;
    mailArrivalTime = nowTs;
  }

  // Update
  previousDistance = currentDistance;
  previousDoorOpen = isDoorOpen;
  previousMailPresent = mailPresent;
  needDisplayUpdate = true;

  // Trigger telemetry publish
  publishTelemetry();
}

// Telemetry publishing Particle webhook
//    - Parameter Name: [Event Name] (e.g., "state", "Door_Open", "CurrentOpenDuration")
//    - Parameter Value: {{{PARTICLE_EVENT_VALUE}}}
void publishSignal(const char *eventName, const String &value)
{
  if (!Particle.connected())
  {
    Serial.printlnf("Not connected - skipping %s", eventName);
    return;
  }

  Serial.printlnf("Publishing %s = %s", eventName, value.c_str());
  bool success = Particle.publish(eventName, value, PRIVATE);

  if (!success)
  {
    Serial.printlnf("WARNING: Failed to publish %s", eventName);
  }
}

void publishTelemetry()
{
  unsigned long nowMs = millis();

  // Update current open duration for current value
  double currentOpenDurationNow = 0;
  if (isDoorOpen && doorOpenedAt != 0)
  {
    currentOpenDurationNow = Time.now() - doorOpenedAt;
  }

  // New publish cycle IOT
  if (!publishInProgress && (nowMs - lastPublishTime >= publishMinIntervalMs))
  {
    publishInProgress = true;
    currentSignalIndex = 0;
    lastPublishTime = nowMs;
    lastSignalPublishTime = nowMs;
    Serial.println("Starting telemetry publish cycle...");
  }

  if (publishInProgress)
  {
    if (nowMs - lastSignalPublishTime >= signalPublishIntervalMs)
    {
      lastSignalPublishTime = nowMs;

      // Publish the current signal
      switch (currentSignalIndex)
      {
      case 0:
        publishSignal("Door_Open", String(isDoorOpen ? 1 : 0));
        break;
      case 1:
        publishSignal("CurrentOpenDuration", String((int)currentOpenDurationNow));
        break;
      case 2:
        publishSignal("LastOpenDuration", String((int)lastOpenDuration));
        break;
      case 3:
        publishSignal("TotalOpenTime", String((int)totalOpenTime));
        break;
      case 4:
        publishSignal("OpenCount", String(openCount));
        break;
      case 5:
        publishSignal("MailPresent", String(mailPresent ? 1 : 0));
        break;
      case 6:
        publishSignal("LifeTimeMailCounter", String(lifetimeMailCounter));
        break;
      case 7:
        publishSignal("MailArrivalTime", String((long)mailArrivalTime));
        break;
      case 8:
        if (currentDistance >= 0.0f)
          publishSignal("Distance", String(currentDistance, 1));
        else
          publishSignal("Distance", "0");
        break;
      case 9:
        if (baselineDistance >= 0.0f)
          publishSignal("BaselineDistance", String(baselineDistance, 1));
        else
          publishSignal("BaselineDistance", "0");
        break;
      }

      currentSignalIndex++;

      if (currentSignalIndex >= TOTAL_SIGNALS)
      {
        publishInProgress = false;
        currentSignalIndex = 0;
        Serial.println("Telemetry publish cycle complete.");
      }
    }
  }
}

// LOGIC and device control Called from the loop()
void handleButton() // controls button press and debouncing
{
  int reading = digitalRead(PIN_BUTTON);

  if (reading != lastButtonState)
  {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay)
  {
    static int buttonState = HIGH;

    if (reading != buttonState)
    {
      buttonState = reading;
      if (buttonState == LOW)
      {
        currentPage = (currentPage + 1) % NUM_PAGES;
        Serial.printlnf("Page changed to: %d", currentPage);
        needDisplayUpdate = true;
      }
    }
  }
  lastButtonState = reading;
}

void handleRgbLed() // controls RGB LED colors
{
  // Dark Mode - force all LEDs off for Blynk
  if (blynkDarkMode)
  {
    digitalWrite(PIN_LED_RED, LOW);
    digitalWrite(PIN_LED_GREEN, LOW);
    digitalWrite(PIN_LED_BLUE, LOW);
    return;
  }

  // Mail present (mailPresent == true) -> GREEN
  // Error states -> RED
  // Otherwise -> OFF

  bool r = false, g = false, b = false;

  if (currentState == MAILBOX_OPEN_TOO_LONG)
  {
    r = true;
  }
  else if (currentState == SENSOR_ERROR)
  {
    r = true;
  }
  else if (mailPresent)
  {
    g = true;
  }

  digitalWrite(PIN_LED_RED, r ? HIGH : LOW);
  digitalWrite(PIN_LED_GREEN, g ? HIGH : LOW);
  digitalWrite(PIN_LED_BLUE, b ? HIGH : LOW);
}

void handleBuzzer() // controls sound mail song and warnign sound
{
  if (blynkMute) // if muted on app nothing plays
  {
    noTone(PIN_BUZZER);
    songActive = false;
    warningActive = false;
    return;
  }

  // Mail Song
  if (songActive)
  {
    playMailSong();
    return;
  }

  // Box Open Too Long Warning
  if (currentState == MAILBOX_OPEN_TOO_LONG)
  {
    if (!warningActive)
    {
      warningActive = true;
      warningStartTime = millis();
    }
    playWarningSound();
  }
  else
  {
    if (warningActive)
    {
      warningActive = false;
      noTone(PIN_BUZZER);
    }
  }
}

void triggerNewMailSong() // starts new mail song
{
  songActive = true;
  songStartTime = millis();
  songNoteIndex = 0;
  Serial.println("Song: New Mail!");
}

void playMailSong() // plays song
{
  // You've Got Mail - CHIME
  int melody[] = {NOTE_C4, NOTE_E4, NOTE_G4, NOTE_C5, NOTE_G4, NOTE_E4, NOTE_C4};
  int noteDurations[] = {4, 4, 4, 4, 4, 4, 4};
  int numNotes = 7;

  unsigned long now = millis();
  unsigned long elapsed = now - songStartTime;

  int totalTime = 0;
  for (int i = 0; i < songNoteIndex && i < numNotes; i++)
  {
    int noteDuration = 1000 / noteDurations[i];
    totalTime += noteDuration;
  }

  if (songNoteIndex < numNotes)
  {
    int noteDuration = 1000 / noteDurations[songNoteIndex];
    int noteStartTime = totalTime;
    int noteEndTime = totalTime + noteDuration;

    if (elapsed >= noteStartTime && elapsed < noteEndTime)
    {
      tone(PIN_BUZZER, melody[songNoteIndex]);
    }
    else if (elapsed >= noteEndTime)
    {
      noTone(PIN_BUZZER);
      songNoteIndex++;
    }
  }
  else
  {
    noTone(PIN_BUZZER);
    songActive = false;
  }
}

void playWarningSound() // plays warnign sound
{
  // Warning sound
  unsigned long now = millis();
  unsigned long elapsed = now - warningStartTime;
  unsigned long cycle = elapsed % 600;

  if (cycle < 300)
  {
    tone(PIN_BUZZER, NOTE_C6);
  }
  else
  {
    tone(PIN_BUZZER, NOTE_C4);
  }
}

// OLED DISPLAY (pritns string directly)
String getStatusString()
{
  if (mailPresent)
    return "  MAIL PRESENT";
  if (currentState == MAILBOX_OPEN_TOO_LONG && isDoorOpen)
    return "  OPEN TOO  LONG";
  if (currentState == SENSOR_ERROR)
    return "SENSOR ERROR";
  if (isDoorOpen)
    return "  BOX OPEN";
  return "  NORMAL";
}

void updateDisplay()
// font and screen control
{
  oled.clear(PAGE);
  oled.setFontType(0);
  oled.setCursor(0, 0);

  if (currentPage == 0)
  {
    // Page 0
    oled.print("Smart Box");
    oled.setCursor(0, 8);

    oled.setCursor(0, 20);
    oled.print("Status: ");
    oled.print(getStatusString());
  }
  else
  {
    // Page 1
    oled.print("Smart Box");
    oled.setCursor(0, 8);
    oled.print("------");

    oled.setCursor(0, 16);
    oled.print("Door: ");
    oled.print(isDoorOpen ? "OPEN" : "CLOSED");

    oled.setCursor(0, 24);
    oled.print("PIR:  ");
    oled.print(isPirMotion ? "MOTION" : "NO");

    oled.setCursor(0, 32);
    oled.print("Dist: ");
    if (currentDistance >= 0)
    {
      oled.print(currentDistance, 1);
      oled.print("cm");
    }
    else
    {
      oled.print("N/A");
    }
  }

  oled.display();
}

// BLYNK INTEGRATION
void updateBlynk()
{
  if (!Blynk.connected())
  {
    return;
  }

  // V0: Dark Mode (Integer)
  int darkModeValue = blynkDarkMode ? 1 : 0;
  Blynk.virtualWrite(0, darkModeValue);

  // V1: Door Status (String)
  Blynk.virtualWrite(1, isDoorOpen ? "OPEN" : "CLOSED");

  // V2: Mute (Integer)
  int muteValue = blynkMute ? 1 : 0;
  Blynk.virtualWrite(2, muteValue);

  // V3: Mail
  Blynk.virtualWrite(3, mailPresent ? "PRESENT" : "NONE");

  // V4: Mail Time In Box (seconds counter)
  int mailTimeInBox = 0;
  if (mailPresent && mailArrivalTime > 0)
  {
    time_t currentTime = Time.now();
    mailTimeInBox = (int)(currentTime - mailArrivalTime);
  }
  Blynk.virtualWrite(4, mailTimeInBox);
  Serial.printlnf("Blynk V4 (Mail Time In Box): %d seconds", mailTimeInBox);

  // V5: Mail Counter History (Integer) - total lifetime mail deliveries
  int mailCounter = (int)lifetimeMailCounter;
  Blynk.virtualWrite(5, mailCounter);
  Serial.printlnf("Blynk V5 (Mail Counter): %d", mailCounter);

  Serial.println("Blynk data updated");
}

// Blynk (app Controls)
BLYNK_WRITE(0) // V0: Dark Mode
{
  int value = param.asInt();                                            // convert Blynk data to integer
  blynkDarkMode = (value == 1);                                         // check if value equals 1 (true/false)
  Serial.printlnf("Blynk Dark Mode: %s", blynkDarkMode ? "ON" : "OFF"); // if true print "on" if not say "off"
}

BLYNK_WRITE(2) // V2: Mute
{
  int value = param.asInt();
  blynkMute = (value == 1);
  Serial.printlnf("Blynk Mute: %s", blynkMute ? "ON" : "OFF");
  if (blynkMute)
  {
    noTone(PIN_BUZZER);
    songActive = false;
    warningActive = false;
  }
}
