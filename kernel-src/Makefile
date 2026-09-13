# SPDX-License-Identifier: GPL-2.0
# Makefile for the haram_guard Linux Security Module
#
# Usage (standalone):
#   make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
#
# Usage (in-tree):
#   Add obj-$(CONFIG_HARAM_GUARD) += haram_guard.o
#   to the top-level Makefile or security/Makefile.

obj-$(CONFIG_HARAM_GUARD) += haram_guard.o

ccflags-y += -Wextra -Wno-unused-parameter -Wall
