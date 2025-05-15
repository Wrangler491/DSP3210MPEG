# DSPMPEG
MPEG 1 Layer II and III decoder and player for AA3000+ Amigas

Requires 68030 or better CPU, DSP3210 on board, 2MB Fast RAM, Amiga OS 3.1 or higher

If you would like to support this development or drop me a than you, please consider using Ko-Fi and making a donation via the Ko-Fi sponsorship link on this repository's main page

DSPMPEG implements mpeg.device using the DSP3210 found on the Amiga AA3000+.  It can decode and play MPEG 1 Layer II and Layer III files with some limitations.  Playback is via Paula in 14 bit stereo sound.

Current limitations - subject to change
- The device operates with a frequency divisor of 2 or 4, so an MPEG 1 Layer II file at 48 kHz will actually be played at 12 kHz or 24 KHz.  The default is a frequency divisor of 4.  A frequency divisor of 1 is not supported.  Layer III files require frequency divisor of 4
- Using an '030 CPU, a fast player is required and one that supports the mpeg.device standard.  AMPlifier is recommended
- Fast forward and rewind are not currently functioning correctly in AMPlifier
- The wrapper for mpeg.devices to become MHI devices (mhimdev) does not function correctly
- Not fully tested yet on CPUs > 030

MPEG 1 Layer III additional limitations
- MPEG 1 Layer III files must be 96kbps or less
- Joint stereo not fully supported

With thanks to Michael Henke and the source code for mpeg.device for Delfina DSP and Stephane Tavenard for MPEGA, both of which provided inspiration for this software 
