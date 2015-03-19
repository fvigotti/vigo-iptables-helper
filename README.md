# Why?
Docker works on iptables, and default-drop-policy or iptables handling could cause issues,  
ie:   
- iptables save and restore could happen while Docker is applying new rules due to container status changes  
- shorewall and other iptables frameworks could flush all rules during changes (there are workarounds but are tricky)  
- iptables flush require docker service restart & restart of all containers!   
  
# How  
ipth handle the firewalling in default-custom-chains which can be inserted into the default chain (in any table) at the top or bottom  
with a forced ( without restrictions )  jump, in those chain that all rules/filters can be inserted

all default-custom-created chains are registered into an array and can be flushed by a method call
  
additional non-default custom chains can be created using ipth dedicated methos `create_chain`   
    
ipth handle the deletion of custom chains deleting their references around the table, then flushing the chain before deleting it ( deletion of a chain in iptables must be handled that way )        

# Usage

- ipth.sh contain all core functions
- ipth-executor require the template to execute & ipth core locations 

- template > must contain a metho called `ipth_template` which will be applied by `ipth-executor` 

ipth-executor syntax:
```bash
ipth-executor templatefile ipthfile action    
action=enable(default)/disable   
```
 

# NB
version check is strict at the moment, it means that template version must be the same as the ipth ( backward compatibility may be always broken up at this stage )


# todo:
documentation & usability guide :)     
v_last_ && v_first_ are strings which must be secure with a tests ( becuase are both used during atuomated creation and atuomated-deletion of chains ) 


# inspirations & resources:
http://www.linuxquestions.org/questions/linux-security-4/yes-sir-another-iptables-management-script-911936/
         -> http://pastie.org/2851019
         
http://daemonkeeper.net/781/mass-blocking-ip-addresses-with-ipset/          

https://github.com/lehmannro/assert.sh/blob/master/assert.sh

http://www.iptables.info/en/iptables-targets-and-jumps.html