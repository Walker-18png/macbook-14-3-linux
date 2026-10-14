// SPDX-License-Identifier: GPL-2.0
/*
 * acpi_bridge_bus: out-of-tree carry of ACPICA PR #1235 (omarchy-pkgs#544,
 * patch 0771) for the MacBookPro14,x Thunderbolt resume.
 *
 * acpi_hw_get_pci_device_info() reads a bridge's Primary Bus Number (0x18)
 * and stores it in pci_id->bus. During resume the register can still hold
 * its reset value 0, so UPSB PCI_Config regions land on host bridge 00:00.0
 * and Apple's firmware polls the wrong device for seconds per controller.
 * The patch keeps the bus derived from the parent bridge instead.
 *
 * The helper is inlined, so this module wraps acpi_hw_derive_pci_id() and,
 * only inside it, makes the 8-bit read of register 0x18 return the bus
 * already in pci_id. The caller then assigns that same bus back, and the
 * following secondary-bus read uses the correct address. AML reads of 0x18
 * outside region setup keep the stock path.
 */
#include <linux/module.h>
#include <linux/kprobes.h>
#include <linux/sched.h>
#include <linux/acpi.h>

#define PCI_CFG_PRIMARY_BUS_NUMBER_REG	0x18

static struct task_struct *deriving;

static unsigned int fixed;
module_param(fixed, uint, 0444);
MODULE_PARM_DESC(fixed, "primary-bus reads that disagreed with the parent-derived bus");

static unsigned int kept;
module_param(kept, uint, 0444);
MODULE_PARM_DESC(kept, "primary-bus reads replaced with the parent-derived bus");

/* acpi_status acpi_hw_derive_pci_id(struct acpi_pci_id *, acpi_handle, acpi_handle) */
static int derive_entry(struct kretprobe_instance *ri, struct pt_regs *regs)
{
	if (cmpxchg(&deriving, NULL, current) != NULL)
		return 1;	/* another derivation in flight: leave this one stock */
	return 0;
}

static int derive_ret(struct kretprobe_instance *ri, struct pt_regs *regs)
{
	cmpxchg(&deriving, current, NULL);
	return 0;
}

static struct kretprobe derive_krp = {
	.kp.symbol_name = "acpi_hw_derive_pci_id",
	.entry_handler = derive_entry,
	.handler = derive_ret,
	.maxactive = 4,
};

struct read_data {
	u64 *value;
	u16 bus;
};

/* acpi_status acpi_os_read_pci_configuration(struct acpi_pci_id *, u32 reg, u64 *value, u32 width) */
static int read_entry(struct kretprobe_instance *ri, struct pt_regs *regs)
{
	struct acpi_pci_id *id = (struct acpi_pci_id *)regs->di;
	struct read_data *d = (struct read_data *)ri->data;

	if (READ_ONCE(deriving) != current ||
	    regs->si != PCI_CFG_PRIMARY_BUS_NUMBER_REG || regs->cx != 8)
		return 1;
	d->value = (u64 *)regs->dx;
	d->bus = id->bus;
	return 0;
}

static int read_ret(struct kretprobe_instance *ri, struct pt_regs *regs)
{
	struct read_data *d = (struct read_data *)ri->data;

	if (regs_return_value(regs) != AE_OK)
		return 0;
	kept++;
	if (*d->value != d->bus) {
		fixed++;
		pr_info("acpi_bridge_bus: primary bus read %llu, keeping parent bus %u\n",
			*d->value, d->bus);
		*d->value = d->bus;
	}
	return 0;
}

static struct kretprobe read_krp = {
	.kp.symbol_name = "acpi_os_read_pci_configuration",
	.entry_handler = read_entry,
	.handler = read_ret,
	.data_size = sizeof(struct read_data),
	.maxactive = 8,
};

static int __init acpi_bridge_bus_init(void)
{
	int ret = register_kretprobe(&read_krp);

	if (ret) {
		pr_err("acpi_bridge_bus: kretprobe acpi_os_read_pci_configuration failed: %d\n", ret);
		return ret;
	}
	ret = register_kretprobe(&derive_krp);
	if (ret) {
		pr_err("acpi_bridge_bus: kretprobe acpi_hw_derive_pci_id failed: %d\n", ret);
		unregister_kretprobe(&read_krp);
		return ret;
	}
	pr_info("acpi_bridge_bus: armed\n");
	return 0;
}

static void __exit acpi_bridge_bus_exit(void)
{
	unregister_kretprobe(&derive_krp);
	unregister_kretprobe(&read_krp);
}

module_init(acpi_bridge_bus_init);
module_exit(acpi_bridge_bus_exit);
MODULE_LICENSE("GPL");
MODULE_VERSION("1.0");
MODULE_DESCRIPTION("Keep parent-derived PCI bus for ACPI bridge regions (ACPICA PR #1235)");
