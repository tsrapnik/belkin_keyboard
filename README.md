# Correctly recognize as keyboard.

Create:

sudo nano /etc/udev/rules.d/99-belkin-bbz002.rules


Add:

SUBSYSTEM=="input", ATTRS{name}=="BELKIN BBZ002", \
  ENV{ID_INPUT_TOUCHSCREEN}="0", \
  ENV{ID_INPUT_TABLET}="0", \
  ENV{ID_INPUT_TABLET_PAD}="0", \
  ENV{ID_INPUT_KEYBOARD}="1", \
  ENV{ID_INPUT_KEY}="1"


Then reload:

sudo udevadm control --reload
sudo udevadm trigger


Unplug / reconnect the device (or reboot).

# Update driver.

Make sure the first line in [Makefile](./Makefile) is `obj-m := hid-magicmouse.o`.

```
make
sudo rmmod hid-magicmouse
sudo insmod ./hid-magicmouse.ko
```
