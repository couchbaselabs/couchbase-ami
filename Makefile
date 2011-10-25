
EC2_HOME        = ./ec2-api-tools-1.4.4.2
EC2_PRIVATE_KEY = ~/.ec2/pk-LNGJGIFNQUNA6GWNURZFDKGB6CLJ7M4W.pem
EC2_CERT        = ~/.ec2/cert-LNGJGIFNQUNA6GWNURZFDKGB6CLJ7M4W.pem
EC2_URL         = https://ec2.us-east-1.amazonaws.com
AMI_ID          = ami-7341831a

INSTANCE_TYPE = m1.xlarge
INSTANCE_HOST = `grep INSTANCE instance-describe.out | cut -f 4`
INSTANCE_ID   = `grep INSTANCE instance-describe.out | cut -f 2`

SSH_KEY = steveyen-key
SSH_CMD = ssh -i ~/.ssh/$(SSH_KEY).pem ec2-user@$(INSTANCE_HOST)

IMAGE_NAME = membase-1.7.2_BasicAmazonLinux64-201109

PKG_BASE = http://builds.hq.northscale.net/releases/1.7.2
PKG_NAME = membase-server-enterprise_x86_64_1.7.2r-20-g6604356.rpm
PKG_KIND = membase

QUOTA_RAM_MB = 1000

image-create: instance-launch \
              instance-prep instance-install instance-cleanse \
              instance-image-create

instance-launch:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-run-instances $(AMI_ID) \
      --block-device-mapping /dev/sdb=ephemeral0 \
      --block-device-mapping /dev/sdc=ephemeral1 \
      --block-device-mapping /dev/sdd=ephemeral2 \
      --block-device-mapping /dev/sde=ephemeral3 \
      --availability-zone us-east-1d \
      --instance-type $(INSTANCE_TYPE) \
      --instance-initiated-shutdown-behavior stop \
      --group couchbase \
      --key $(SSH_KEY) > instance-describe.out
	sleep 20
	$(MAKE) instance-describe

instance-describe:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-describe-instances $(INSTANCE_ID) > instance-describe.out

instance-prep:
	$(SSH_CMD) -t sudo yum -y install openssl098e gcc gdb iotop sysstat systemtap emacs
	$(SSH_CMD) -t "grep -q xfs /proc/filesystems || sudo modprobe xfs"
	echo TODO: EBS volume attachment goes here, 30GB per node?

instance-install:
	$(SSH_CMD) wget -O $(PKG_NAME) $(PKG_BASE)/$(PKG_NAME)
	$(SSH_CMD) -t sudo rpm -i $(PKG_NAME)
	sed -e s,@@PKG_NAME@@,$(PKG_NAME),g README.txt.tmpl | \
      sed -e s,@@PKG_KIND@@,$(PKG_KIND),g > README.txt.out
	scp -i ~/.ssh/$(SSH_KEY).pem README.txt.out \
      ec2-user@$(INSTANCE_HOST):/home/ec2-user/README.txt
	$(SSH_CMD) -t /opt/membase/bin/membase cluster-init -c 127.0.0.1 \
      --cluster-init-username=Administrator \
      --cluster-init-password=$(INSTANCE_ID) \
      --cluster-init-ramsize=$(QUOTA_RAM_MB)

instance-cleanse:
	$(SSH_CMD) rm -f /home/ec2-user/.bash_history /home/ec2-user/.ssh/authorized_keys

instance-image-create:
	$(EC2_HOME)/bin/ec2-create-image -n $(IMAGE_NAME) $(INSTANCE_ID)

clean:
	rm -f instance-describe.out
