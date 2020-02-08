# terraform-ansible-lab-environment
Deploy Ansible lab environment using Terraform and Ansible. If you want to 
test your Playbooks using a clean lab environment, this is a nice way to do so. 
It will build one Ansible management and four target VM's. After testing you 
can destroy it with one command.

Requirements
------------

Any pre-requisites that is needed for a successful deployment.

 - Terraform with [libvirt](https://github.com/dmacvicar/terraform-provider-libvirt) provider
 - Ansible
 - Libvirt with KVM
 - Base CentOS (or other Linux OS) template with passwordless root access
 - Netcat for detecting the SSH port

Template Image
--------------

Create a template VM image with SSH deamon running.
Make sure the libvirt image is in place with the public key of the main host.
This way Ansible can start the playbook once the SSH port of the VM is up.
Edit the resources.tf files and set the source.

Default source in resources.tf is:

    source = "/var/lib/libvirt/images/CentOS-7.x86_64-kvm-and-xen.qcow2"

Tip: Keep the size of the template image as small as possible:

    dd if=/dev/zero of=/root/zero status=progress bs=4M
    rm -f /root/zero
    shutdown -h now

Then convert the qcow2 image using the following command:

    kvm-img convert -O qcow2 original_image.qcow2 new_image.qcow2


Example
-------

Execute build.sh script to start building the host.

    # ./build.sh 

To destory the VM:

    # ./build destroy

License
-------

See LICENSE

