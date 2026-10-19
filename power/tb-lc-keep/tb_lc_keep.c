// SPDX-License-Identifier: GPL-2.0
/*
 * tb_lc_keep: skip tb_lc_set_sleep() on Thunderbolt 3 host routers during
 * suspend-to-idle. Out-of-tree carry of omarchy-pkgs#596 patch 0664.
 *
 * On the MacBookPro14,3 (two Alpine Ridge JHL6540 hosts, native connection
 * manager) the LC sleep bit makes the host router stop answering: after the
 * first s2idle both domains read all-ones, tb_cfg_read fails with -108 and
 * pciehp removes the USB-C xHCIs until a reboot. In s2idle the host router
 * stays powered, so the bit is not needed there. Device routers, S3,
 * hibernation and runtime PM keep the stock path.
 */
#include <linux/module.h>
#include <linux/kprobes.h>
#include <linux/suspend.h>
#include <linux/device.h>
#include <linux/string.h>
#include <linux/objtool.h>
#include <linux/utsname.h>
#include <linux/version.h>
#include <asm/linkage.h>

/* Same stub as just_return_func in arch/x86/lib/error-inject.c (not exported). */
void tb_lc_keep_return(void);
asm(
	".text\n"
	".type tb_lc_keep_return, @function\n"
	".globl tb_lc_keep_return\n"
	ASM_FUNC_ALIGN
	"tb_lc_keep_return:\n"
		ANNOTATE_NOENDBR "\n"
		ASM_RET
	".size tb_lc_keep_return, .-tb_lc_keep_return\n"
);

static unsigned int skipped;
module_param(skipped, uint, 0444);
MODULE_PARM_DESC(skipped, "host-router LC sleep calls skipped so far");

/*
 * Tested kernel series. This module hooks internal functions and reads their
 * arguments from registers, so a new series can break it without a build
 * error. Check the hooked functions in the new source, then raise TESTED_MAX.
 */
#define TESTED_MIN	KERNEL_VERSION(7, 2, 0)
#define TESTED_MAX	KERNEL_VERSION(7, 3, 0)	/* exclusive */

static bool force;
module_param(force, bool, 0444);
MODULE_PARM_DESC(force, "arm on a kernel series this module was not tested on");

static bool tested_kernel(const char *mod)
{
	if (LINUX_VERSION_CODE >= TESTED_MIN && LINUX_VERSION_CODE < TESTED_MAX)
		return true;
	if (force) {
		pr_warn("%s: kernel %s is untested, armed because force=1\n", mod, init_utsname()->release);
		return true;
	}
	pr_err("%s: kernel %s is untested, not armed. See power/README.md, Runtime kernel patches\n",
	       mod, init_utsname()->release);
	return false;
}

/* int tb_lc_set_sleep(struct tb_switch *sw); struct tb_switch starts with struct device. */
static int pre(struct kprobe *p, struct pt_regs *regs)
{
	struct device *dev = (struct device *)regs->di;
	const char *name;
	size_t n;

	if (pm_suspend_target_state != PM_SUSPEND_TO_IDLE)
		return 0;
	/* Routers are named "<domain>-<route>"; the host router has route 0. */
	name = dev_name(dev);
	n = name ? strlen(name) : 0;
	if (n < 2 || strcmp(name + n - 2, "-0"))
		return 0;

	skipped++;
	dev_info(dev, "tb_lc_keep: suspend-to-idle, not setting LC sleep\n");
	regs->ax = 0;
	instruction_pointer_set(regs, (unsigned long)tb_lc_keep_return);
	return 1;
}

static struct kprobe kp = {
	.symbol_name = "tb_lc_set_sleep",
	.pre_handler = pre,
};

static int __init tb_lc_keep_init(void)
{
	int ret;

	if (!tested_kernel("tb_lc_keep"))
		return -EPERM;
	ret = register_kprobe(&kp);
	if (ret)
		pr_err("tb_lc_keep: register_kprobe(tb_lc_set_sleep) failed: %d\n", ret);
	else
		pr_info("tb_lc_keep: armed at %pS\n", kp.addr);
	return ret;
}

static void __exit tb_lc_keep_exit(void)
{
	unregister_kprobe(&kp);
}

module_init(tb_lc_keep_init);
module_exit(tb_lc_keep_exit);
MODULE_SOFTDEP("pre: thunderbolt");
MODULE_LICENSE("GPL");
MODULE_VERSION("1.0");
MODULE_DESCRIPTION("Keep Thunderbolt 3 host routers awake in s2idle (MacBookPro14,x)");
