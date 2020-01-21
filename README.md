# terraform-ansible-lab-practice
Deploy Ansible lab environment using Terraform and Ansible. If you want to test your Playbooks using a clean lab environment, this is a nice way to do so. It will build one Ansible management and four target VM's. After testing you can destroy it with one command.

Requirements
------------

Any pre-requisites that is needed for a successful deployment.

 - Terraform
 - Libvirt
   - Passwordless login to a CentOS VM template
 - Netcat (for detecting SSH port)

Template Image
--------------

Create a template VM image with SSH deamon running.
Make sure the libvirt image is in place with the public key of the main host.
This way Ansible can start the playbook once the SSH port of the VM is up.
Edit the docker.tf file and set the source.

Default source in docker.tf is:

    source = "/var/lib/libvirt/images/openSUSE-Tumbleweed-JeOS.x86_64-kvm-and-xen.qcow2"

Example
-------

Execute build.sh script to start building the host.

    # ./build.sh 
    Usage:
    
      apply | destroy
    
      -a            Apply builds or changes infrastructure
      -d            Destroy Terraform-managed infrastructure
      -n <iprange>  When building, detect new host in this IP range (default 192.168.)

To apply the build:

    # ./build apply

To destory the VM:

    # ./build destroy

License
-------

See LICENSE

