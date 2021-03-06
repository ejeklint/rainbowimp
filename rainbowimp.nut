//
// WS2810 RGB LED Driver Controller and Demo usage
//

//
// A selection of predefined RGB colours. Add to taste.
//
// RGB colours
/*local Colour = {
	red = "\xff\x00\x00",
	green = "\x00\xff\x00",
	blue = "\x00\x00\xff",
	yellow = "\xff\xaa\x00",
	orange = "\xff\x80\x00",
	purple = "\x80\x00\xff",
	white = "\xff\xff\xff",
	off = "\x00\x00\x00" 
}*/
// BGR colours
local Colour = {
	red = "\x00\x00\xff",
	green = "\x00\xff\x00",
	blue = "\xff\x00\x00",
	yellow = "\x00\xaa\xff",
	orange = "\x00\x40\xff",
	purple = "\x60\x00\x40",
	white = "\xff\xff\xff",
	off = "\x00\x00\x00" 
}

//
// Patterns
//
local Pride = [Colour.red, Colour.orange, Colour.yellow, Colour.green, Colour.blue, Colour.purple];
local Sweden = [Colour.blue, Colour.yellow, Colour.blue];
local USA = [Colour.blue, Colour.white, Colour.blue, Colour.red, Colour.white, Colour.red, Colour.white, Colour.red];
local Norway = [Colour.red, Colour.red, Colour.red, Colour.white, Colour.blue, Colour.blue, Colour.white, Colour.red, Colour.red, Colour.red];

//
// Class that handles an array of WS2801 RGB LED controllers in a LED strip
// Uses spi257 so connect the strips clock to pin 5 and data to pin 7 (MOSI)
//
class WS2801 {
	ledCount = null;
	strip = null;

	//
	// Constructs a strip with certain Number of LEDs.
	// 
	constructor(noOfLEDs) {
		ledCount = noOfLEDs;
		strip = blob(ledCount * 3);
		hardware.spi257.configure(SIMPLEX_TX, 5000); // Limit to 5MHz clock
		imp.sleep(0.01);
	}

	//
	// Set colour of entire strip with setColour(Colour.blue)
	// Set colour of 4th LED with setColour(Colour.blue, 3)
	// Set colour of several LEDs with setColour(Colour.blue, [1,2,5,8,11])
	// Unless a third parameter is true, previous strip colors will be lost. To keep them
	// call with for example setColour(Colour.blue, [1,2,3], true)
	//
	function setColour(colour, leds = null, keepValues = false) {
		if (!keepValues) {
			// Allocate a new and clean blob (all leds off)
			strip = blob(ledCount * 3);
		}
		if (leds == null || leds == "null") {
			// Set whole strip to same colour
			for (local i = 0; i < ledCount; i++) {
				setLedColour(i, colour);
			}
		} else if (typeof leds == "array") {
			// Set leds in array to colour
			foreach(i in leds) {
				setLedColour(i, colour);
			}
		} else {
			// Set a single led to colour
			setLedColour(i, colour);
		}
		writeToStrip();
	}

	//
	// Fills the strip in a "swipe" manner from first to last LED.
	// Default wait between each step is 20 ms.
	//
	function colourWipe(colour, wait = 0.02) {
		for (local i = 0; i < ledCount; i++) {
			setLedColour(i, colour);
			writeToStrip();
			imp.sleep(wait);
		}
	}

	//
	// Loops over all colours in 256 steps. All LEDs have the same colour.
	//
	function rainbow(wait = 0.02) {
		for (local j = 0; j < 256; j++) {
			for (local i = 0; i < ledCount; i++) {
				local colour = wheel((i+j) % 255);
				setLedColour(i, colour);
			}
			writeToStrip();
			imp.sleep(wait);
		}
	}

	//
	// Fancy effect demo that creates a rainbow distributed over the strip and the cycles the colours.
	// Default values are 1 cycle and 20 ms between each colour change. Quite tedious, really...
	//
	function rainbowCycle(cycles = 1, wait = 0.02) {
		for (local j = 0; j < 256 * cycles; j++) {
			for (local i = 0; i < ledCount; i++) {
				local colour = wheel(((i*256 / ledCount) + j) % 255);
				setLedColour(i, colour);
			}
			writeToStrip();
			imp.sleep(wait);
		}
	}

	//
	// Set a pattern over the strip. Padding will be added so pattern i centered on the strip.
	//
	function setPattern(pattern) {
		strip = blob(ledCount * 3); // Get a fresh strip
		local ledsPerColour = math.floor(ledCount / pattern.len());
		local padding = math.floor(ledCount % pattern.len() / 2);
		local j = 0;
		foreach (col in pattern) {
			for (local i = 0; i < ledsPerColour; i++) {
				setLedColour(j*ledsPerColour+i+padding, col);
			}
			j++;
		}
		writeToStrip();
	}

	//
	// Sets color values for each led at position
	//
	function setLedColour(led, colour) {
		local led = led.tointeger();
		strip[led*3] = colour[0];
		strip[led*3+1] = colour[1];
		strip[led*3+2] = colour[2];
	}

	//
	// Shift the led strip one led per call.
	//
	function shift() {
		// Led 0 should be 1, 1 should be 2 etc
		local newStrip = blob(ledCount * 3);

		for (local i = 0; i < ledCount * 3; i++) {
			newStrip[(i+3)%(ledCount*3)] = strip[i];
		}
		strip = newStrip;
		writeToStrip();
	}

	//
	// Rotate strip.
	// Defaults to one complete turn per second.
	// Note that you can rps to fractional value too.
	//
	function rotate(turns = 1.0, rps = 1.0) {
		local stepDelay = 1.0 * rps / ledCount; // Make sure math is done with floats by multiplying with 1.0
		for (local i = 0; i < math.floor(turns * ledCount); i++) {
			shift();
			imp.sleep(stepDelay);
		}
	}

	//
	// Writes out data to strip and assures it latches before execution continues.
	//
	function writeToStrip() {
		hardware.spi257.write(strip);
		// Wait so strip "latches"
		imp.sleep(0.001);
	}

	//
	// Returns a colour positioned at 'position' on a colour wheel with 256 steps (I think - nicked this code).
	// 
	function wheel(position) {
		local colour = blob(3);
		if (position < 85) {
			colour[0] = position * 3;
			colour[1] = 255 - position * 3;
			colour[2] = 0;
			return colour;
		} else if (position < 170) {
			position = position - 85;
			colour[0] = 255 - position * 3;
			colour[1] = 0;
			colour[2] = position * 3;
			return colour;
		} else {
			position = position - 170;
			colour[0] = 0;
			colour[1] = position * 3;
			colour[2] = 255 - position * 3;
			return colour;
		}
	}
}

class LedStripInput extends InputPort
{
	stripHandler = null;
	constructor(strip) {
		base.constructor();
		stripHandler = strip;
	}

	function set(value) {
		server.log("value: " + value);
		server.log("value.effect: " + value.effect + ", value.colour: " + value.colour + ", value.leds: " + value.leds);
		stripHandler[value.effect](Colour[value.colour], value.leds);
	}
}

//
// Example use below
//
server.log("Enjoy the show!");

// Instantiate
local strip = WS2801(32);

// Register with the server
imp.configure("MagicLedStrip", [ LedStripInput(strip) ], []);

// Set all to off
strip.setColour(Colour.white);
imp.sleep(0.5);

// Pride
strip.setPattern(Pride);

// And rotate it, for the world!
strip.rotate(4, 0.25);

strip.setPattern(Sweden);
imp.sleep(2);
strip.setPattern(USA);
imp.sleep(2);
strip.setPattern(Norway);
imp.sleep(2);

strip.rainbowCycle(2, 0.005);
strip.setColour(Colour.white);

/*
// Set all to white
strip.setColour(Colour.white);
imp.sleep(2.0);
strip.setColour(Colour.red);
imp.sleep(1.0);
strip.setColour(Colour.blue);
imp.sleep(1.0);

// Swipe in red to all LEDs
strip.colourWipe(Colour.red);
strip.colourWipe(Colour.green);
strip.colourWipe(Colour.blue);
imp.sleep(1.0);

// Set first LED to red
strip.setColour(Colour.red, 0);
imp.sleep(0.5);

// Rotate the strip 3 times, 1 rotation/s
strip.rotate(3, 1);

// Set all LEDs with even index to orange
strip.setColour(Colour.orange, [0,2,4,6,8,10,12,14,16,18]);
imp.sleep(1.0);

// Set all LEDs with odd index to green and keep the previous setting
strip.setColour(Colour.green, [1,3,5,7,9,11,13,15,17,19], true);
imp.sleep(1.0);

// Set all LEDs with even index to orange without keeping previous setting
strip.setColour(Colour.orange, [0,2,4,6,8,10,12,14,16,18]);
imp.sleep(1.0);

// Do a fancy rainbow
//strip.rainbowCycle(2, 0.005);

// Pride
strip.setPattern(Pride);

// And rotate it, for the world!
strip.rotate(4, 0.25);

strip.setPattern(Sweden);
imp.sleep(2);
strip.setPattern(USA);
imp.sleep(2);
strip.setPattern(Norway);
imp.sleep(2);

strip.rainbowCycle(2, 0.005);
strip.setColour(Colour.white);
*/