#!/usr/bin/python

import gobject
import gtk
import appindicator
import subprocess
import re

# Depends on gnome-settings-daemon
MAXSTEPS = 15

closest = lambda num,list:min(list,key=lambda x:abs(x-num))

def menuitem_response(w, buf):
  buf = re.sub('[^\d]', '', buf)
  brightness = str(brightness_settings[int(buf)])
  subprocess.call(['pkexec','/usr/lib/gnome-settings-daemon/gsd-backlight-helper','--set-brightness',brightness])
  create_menu(ind)

def scroll_wheel_icon(w, m, d):
  curr_brightness = get_curr_brightness()

  if int(d) == int(gtk.gdk.SCROLL_UP):
    curr_brightness = curr_brightness -1
    if curr_brightness == -1:
      curr_brightness = 0
  elif int(d) == int(gtk.gdk.SCROLL_DOWN):
    curr_brightness = curr_brightness + 1
    if curr_brightness > len(brightness_settings)-1:
      curr_brightness = len(brightness_settings)-1

  brightness = str(brightness_settings[curr_brightness])
  subprocess.call(['pkexec','/usr/lib/gnome-settings-daemon/gsd-backlight-helper','--set-brightness',"%s" % brightness])
  create_menu(ind)

def get_curr_brightness():
  p = subprocess.Popen(['pkexec','/usr/lib/gnome-settings-daemon/gsd-backlight-helper','--get-brightness'], stdout=subprocess.PIPE)
  curr_brightness = int(p.communicate()[0])
  c = closest(curr_brightness, brightness_settings)
  return brightness_settings.index(c)

def get_brightness_settings():
  if max_brightness < MAXSTEPS:
    bs = range(0, max_brightness, 1)
  else:
    bs = range(0, max_brightness, max_brightness/MAXSTEPS)
  bs.append(max_brightness)
  return bs

def get_max_brightness():
  mb = 0
  try:
    p = subprocess.Popen(['pkexec','/usr/lib/gnome-settings-daemon/gsd-backlight-helper','--get-max-brightness'], stdout=subprocess.PIPE)
    mb = int(p.communicate()[0])
  except:
    mb = 0
  return mb

def create_menu(ind):
  curr_brightness = get_curr_brightness()

  menu = gtk.Menu()

  if max_brightness == 0:
    menu_items = gtk.MenuItem("No backlights were found on your system")
    menu_items.set_sensitive(False)
    menu.append(menu_items)
    menu_items.show()
  else:
    for i in range(0, len(brightness_settings)):
      buf = "%d" % i
      if i == curr_brightness:
        buf = u"%d \u2022" % i

      menu_items = gtk.MenuItem(buf)
      menu.append(menu_items)
      menu_items.connect("activate", menuitem_response, buf)
      menu_items.show()

  # show the items
  ind.set_menu(menu)

ind = appindicator.Indicator ("indicator-brightness",
                              "/usr/share/notify-osd/icons/gnome/scalable/status/notification-display-brightness-full.svg",
                              appindicator.CATEGORY_HARDWARE)
ind.set_status (appindicator.STATUS_ACTIVE)
ind.connect("scroll-event", scroll_wheel_icon)

max_brightness = get_max_brightness()
brightness_settings = get_brightness_settings()

if __name__ == "__main__":
  create_menu(ind)
  gtk.main()
