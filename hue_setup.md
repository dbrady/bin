# Hue Lights Arrangement
* 4 - Office Spotlight
* 5 - Main Floor Office Lighstrip
* 9 - Upstairs Office Lightstrip
* 10 - Office Light Fixture (North Bulb)
* 11 - Office Light Fixture (South Bulb)

# Setup Instructions

Taken from https://developers.meethue.com/develop/get-started-2/ which was
still live as of September 2021.

Step 1: Make sure the bridge is on the network. This is probably a given but
tl;dr all three lights should be lit up and blue.

Step 2: Find the HUE bridge's IP address on the LAN. It's in the phone app
under settings. Set this as HUE_IP; it's probably 192.168.0.66. Visit
http://192.168.0.66/debug/clip.html (set to the correct IP) to verify you can
connect to the bridge. Hint: you gotta be on the wired LAN, it doesn't accept
haxxorz coming in over the wifi. (I mean, except for all the vulnerabilities
in the bulbs themselves, but that's for haxxorz only. Legitimate admins are
locked out of this route because security theater.)

Step 3. Generate an API key. In the CLIP interface, put /api/newdeveloper in
the URL box and click the GET button. It will fail because this laptop is not
recognized. We need to tell the bridge to create a resource for us.

Step 4. Fill out the clip form again, and be ready--when you click POST you'll
have 30 seconds to physically access the bridge and hit the link button.

URL: /api
Body: {"devicetype":"my_hue_app#my_device"}

In Body, CHANGE my_hue_app and my_device to match whatever we're doing. They
use "my_hue_app#iphone peter", so I'm thinking we set it to my_hue_app and
this laptop hostname, e.g. "my_hue_app:Mac1205Pro"


POST

Step 5. RUN AND PRESS THE BUTTON YOU HAVE 30 SECONDS OR LESS.

Step 6. Come back and click POST again, this time you should get a response
like:

[
  {
    "success": {
        "username": "xyzxyzetc"
    }
  }
]

Step 7. Put this in ~/.private as

export HUE=xyzxyzetc
