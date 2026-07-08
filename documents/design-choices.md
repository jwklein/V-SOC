# Design Choices

This document outlines the design approach, decisions, and reasoning behind
V-SOC. It covers what was built, what alternatives were considered, and why the
tradeoffs landed where they did.

## Deployment Approach: Heavy Templates, Thin Provisioning

V-SOC uses a **heavy-template, thin-provisioning** pattern. Each component:
OPNsense firewall, Wazuh manager-indexer, Wazuh dashboard, Suricata (running on
OPNsense), Cowrie honeypot, Metasploitable3 target, Kali attacker boxes, and the
pentest-gpt platform, is baked into a dedicated Proxmox golden image with all
package dependencies installed and all infrastructure-agnostic configuration
already applied. At deployment time, Terraform clones templates into a topology
and Ansible performs only the runtime-specific work: primarily manager IP
insertion and service management.

Infrastructure-specific configuration is handled through one of two paths:

- Filesystem configuration baked directly into the golden image, for anything
  that does not vary between deployments.
- Jinja2 templates rendered by Ansible at runtime, for anything that does IP
  addresses, cluster keys, generated secrets.

The result is that runtime work is minimized, which is what enables the ~8
minute deploy from a single `deploy.sh` invocation to a functional SOC topology.
It also simplifies development and maintenance: Ansible playbooks stay short and
focused because the images carry the weight, and each service's baseline config
lives in one place the image rather than being reconstructed by long
provisioning scripts on every run.

Storage cost is roughly 220 GB across all templates, with about half of that in
the Wazuh manager-indexer node. This is the deliberate cost of the pattern:
trading disk for provisioning speed and configuration clarity.

A second function of the image layer is worth naming, because it becomes
relevant to the persistence discussion below. The golden image is also the
natural home for **pre-loaded, lesson-specific state**. A component that needs
to start with data already in place, a Wazuh manager seeded with historical
alerts for a forensic exercise, a target already carrying a specific compromise,
becomes a lesson-specific image derived from the base image and configured by the insructor. The same IaC pipeline clones it like any other. Persistence and parameterization compose in
this design rather than trading off against each other.

## Design Choice: IaC vs Snapshot-Based Provisioning

The simplest alternative would be to build the SOC topology once by hand,
snapshot the resulting VMs in a working state, and revert or clone the snapshots
on demand. This is well supported natively by Proxmox, needs no external
tooling, and would have made the lab operational in a fraction of the time the
IaC pipeline took to build. It is a legitimate approach and the right baseline
to justify against.

Four factors made IaC the better fit for this project's goals.

### Visibility

A snapshot-based approach ships a set of opaque disk images as the product.
Reviewing what the environment actually is requires access to the Proxmox
cluster that holds the snapshots. The environment's *structure*, how VMs are
segmented across bridges, how they are sized, what varies per deployment and
what does not, is not recoverable from the artifact on its own.

With IaC, the definition of the environment *is* the artifact. Terraform
describes the topology; Ansible playbooks and Jinja2 templates describe every
runtime configuration; the whole thing is a repository that can be read without
touching the cluster. The lab is legible from its source, which is what lets it
double as a documented, reviewable body of work rather than a set of disks.

### Mutability Under Change

Snapshots are not strictly immutable: a base VM can be updated and
re-snapshotted. The real problem is that snapshot updates are **opaque under
change**. There is no diff between last week's snapshot and this week's, no
review of what a modification touched, no way to recover intent from the
artifact. Change history lives in external notes, not in the thing itself.

IaC changes are legible. Tuning a Wazuh rule, adjusting a Suricata signature, or
re-segmenting the network shows up as a diff on a `.tf` file or a `.j2`
template, with the intent visible in version control. Because a central part of
V-SOC's value is the breadth of lesson designs the platform can support, the
ability to modify the environment coherently and traceably is foundational, not
a convenience.

Concretely: moving the network stack, renumbering a segment, relocating the
Wazuh node, is a variable change and a re-apply under IaC, with the diff
captured in history. Under snapshots it is a manual reconfiguration of running
VMs followed by re-templating, verifiable only against the prior snapshot, which
is itself opaque.

### Drift Resistance

Security lab work is iterative by nature. Rules get tuned, decoders get
adjusted, scenarios get added, misconfigurations get found and fixed. Under a
snapshot workflow, each such change forks: it either lives only in the running
VM and is lost on revert, or it becomes a new snapshot that now diverges from
prior snapshots and from any external documentation.

IaC forces every change back through the code. The declared state and the
running state stay coherent because code is the only path by which a change
persists. This is a daily-use benefit that compounds over the life of the
project, the lab and its own description do not drift apart.

### Topology Parameterization

The point usually stated as "IaC scales better" is more precisely that IaC
parameterizes not just IP addresses but topology itself. Different lesson plans:
swap the target, add a second sensor, stand up parallel red/blue topologies
become variable changes rather than fresh hand-built environments. This is the
same capability the roadmap points at: a further encapsulating program that
accepts a list of topology names and proliferates the associated subnets, IPs,
and documentation from the existing deployment routine.

The snapshot equivalent would be per-VM network parameterization at first boot,
typically via cloud-init or an OS-specific first-boot script. That is not
uniformly available across V-SOC's guest mix:

- **OPNsense** (FreeBSD) has no official cloud-init support. Community ports
  exist but are fragile and not something to build a pipeline on. Its canonical
  first-boot path is its own importable config format, which is what the
  bootstrap-then-configure stage handles instead.
- **Metasploitable3 (Windows Server 2008)** predates cloudbase-init in any
  workable form, and the 2008-era Windows automation surface makes scripted
  network configuration painful even where it is possible. As the README notes,
  this guest sometimes needs a manual console interaction before it will even
  DHCP. It is not a candidate for hands-off first-boot parameterization.
- **Older Ubuntu variants** used in some Metasploitable3 builds carry cloud-init
  but in the legacy ifupdown format rather than netplan, a different config
  layout than the modern guests.
- **Kali and modern Ubuntu** work cleanly with cloud-init, though not by
  default.

Supporting parameterization across this mix via cloud-init would mean
maintaining a different first-boot mechanism per OS family; exactly the kind of
per-guest bespoke work that erodes the simplicity argument for snapshots.

The underlying reason IaC handles this cleanly is architectural: **the
abstraction lives above the guest, not inside it.** Terraform and Ansible
configure guests from the outside, over SSH or the Proxmox layer. The guest does
not need to know it is being managed, does not need to run first-boot logic, and
does not need to participate in its own provisioning. For a heterogeneous lab
with legacy guests, this outside-in approach is fundamentally more robust than
any inside-out alternative, and it is what makes the heavy-template pattern work
across such varied operating systems in the first place.

### Tradeoffs Accepted

The IaC approach is not costless. The choice was made with the following
understood.

**Slower per-cycle iteration.** A full destroy-and-reapply takes ~8 minutes; a
snapshot revert takes seconds. For a workflow built around "attack, observe,
revert, re-attack" against a fixed environment, snapshots win on wall-clock
time. V-SOC accepts this because its primary iteration mode is on configuration
and topology, not repeated attack cycles against static state.

**Significant upfront tooling investment.** Reliable provisioning required
solving Proxmox provider behavior, MAC pinning for deterministic DHCP, and glue
between Terraform state and Ansible inventory. The platform migration from
OpenStack to Proxmox mid-project absorbed a large share of this cost. None of it
is visible in the final artifact, but all of it was real effort a snapshot
workflow would have avoided.

**No built-in persistence across resets mitigated by the image layer.** A
snapshot preserves accumulated data: a week of Wazuh alerts, tuned rules, a
staged compromise, trivially. Pure IaC destroys this on rebuild or requires
bolted-on persistence. V-SOC's heavy-template pattern provides the middle
ground described above: where a lesson plan needs pre-loaded state, that state is
baked into a lesson-specific golden image, and lesson-plan-specific snapshots of
both the images and the IaC code can be organized into versions on an as-needed
basis. This shifts the tradeoff from "persistence is impossible" to "persistence
lives in the image layer at the cost of image proliferation". Disk grows with
the number of lesson variants, while the parameterization and legibility
benefits are preserved.

These costs were judged acceptable given the priorities above: legibility of the
artifact, mutability under change, drift resistance during iterative work, and
topology parameterization across a heterogeneous guest mix. A different set of
priorities, such as pure speed of iteration on a single fixed topology, would
legitimately point toward the snapshot approach instead.

## Bootstraped Deployment Model
The deployment routine is split into two stages, sequenced around a bootstrap IP baked into the OPNsense template's WAN interface. The reason for the split is a dependency-ordering constraint: OPNsense is the only path from vmbr0 (the controller's segment) to vmbr10 (the lab segment), and it is also vmbr10's gateway and DHCP server. Nothing inside vmbr10 can be provisioned or reached until the bridge exists and OPNsense is configured to route and serve it. Therefore, so the firewall must be  configured before the main stage provisions anything downstream.

OPNsense is FreeBSD based, so it does not support cloud-init natively. Therefore we have two options for how OPNsense can be configured:
 - DHCP WAN address, Static API LAN address
    - This requires querying the upstream dhcp server to resolve the wan address of OPNsense
    - The LAN address would still need to be configured as the upstream gateway & dhcp server of vmbr10 via API xml injection
 - Static WAN address, Static API LAN address
    - Hard-Baking a 'bootstrap ip' into the opnsense template's WAN nic
    - The LAN address would again need to be configured as the upstream gateway & dhcp server of vmbr10 via API xml injection

There are **two reasons** why the bootstrap ip is the preferred method. 
First is **least additional work**. In both cases, an xml injection is required to configure the ip addresses of the opnsense interfaces. Choosing to update the wan address via the same command constitutes one line adjustment of a variable insertion in a j2 template. Comparatively, dhcp would require a whole process of querying the dhcp server to resolve the wan ip just to have less control over it.

Secondly is the **placement of the dependency boundary**. By choosing to assign a bootstrap ip address, we relinquish the requirement of managing the upstream dhcp server of vmbr0 from the requirements of our environment, which is fairly significant. The only upstream requirement is that the bootstrap IP be excluded from the vmbr0 DHCP pool, a one-time configuration on the upstream server.

Once OPNsense is up, the controller's SSH config file describes routes to LAN hosts via a ProxyJump through the firewall as needed. Ansible reads this natively, so no routing adjustments are needed.

## Configuration Authority: Whole-File Templating
Runtime-configured files (ossec.conf being the extreme case) are stored as jinja2 templates and rendered whole over their destination paths by Ansible's template module.  This was a deliberate choice over inline edits/replacements. 

The governing principle is single-owner authority: the management plane should hold complete authority over the configuration it manages. A file whose contents depend on runtime values is owned in full by the controller. The pre-existing file on disk has no influence on the result bears no influence over the result. The running configuration is therefore invariant to the image's boot state, to prior partial runs, and to whatever a package upgrade left on disk.

Line-level editing violates this by making the image and the Ansible run co-authors of the same file. The final state depends on both the baseline on disk and the edits applied over it. Ansible's lineinfile and replace modules are idempotent, but their dependence on the initial state of the file requires tracking and coordination of the Golden Image state with the Ansible code; which is both practically and philosophically messy.

ossec.conf forces the point. It is long, deeply nested, and built from multiple top-level <ossec_config> blocks merged at parse time, with the runtime-dependent values of indexer host, cluster node address and key, the syslog <remote> block and its allowed-ips entries scattered throughout. Line-editing a dozen values into that structure safely is substantially more fragile than rendering the whole file from a template where the structure is fixed and only the variables move. Furthermore, the <remote> block's structure: transport, protocol, allowed sources, is itself a design decision, not just a set of values. Rendering the whole file means those decisions live in the management plane where they can be changed and reviewed, rather than being frozen into the image. In development, syslog was manually configured this way.

The tradeoff is that the template becomes permanently authoritative: when an upstream package ships a new default ossec.conf with additional keys, those keys are silently discarded rather than merged. This is accepted because template updates are re-derived from the shipped default at golden-image rebuild time, which is the same point at which the package version changes.

## Layered Responsibilities

A useful way to read the whole design is as a separation of concerns across
three layers, each doing the one thing it is best at:

- The **image layer** owns *what state a component starts with*. This includes installed
  packages, baseline config, and any lesson-specific pre-loaded data.
- The **Terraform layer** owns *how components compose into a topology*:  bridges,
  clones, network resources, and the two-stage bootstrap/main provisioning.
- The **Ansible layer** owns *what runtime-specific configuration binds them
  together*, IP insertion, service management, and agent enrollment.

Each layer hands off cleanly to the next. The weaker version of this design would
try to make Terraform solve persistence with bolt-on volumes, or make images
solve topology by snapshotting a pre-networked cluster as a unit. Keeping each
layer to its own responsibility is what lets persistence and parameterization
coexist rather than compete.