obj-m += hid-apple.o

# Newer kernels (e.g. 7.2) moved the battery fields of struct hid_device into a list.
ccflags-y += $(shell grep -qs 'struct list_head batteries' \
	$(srctree)/include/linux/hid.h && echo -DHID_HAS_BATTERY_LIST)

KDIR ?= /lib/modules/$(shell uname -r)/build

.PHONY: all modules clean

all: modules

modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
