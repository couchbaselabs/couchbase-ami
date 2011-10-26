
EC2_HOME        = ./ec2-api-tools-1.4.4.2
EC2_PRIVATE_KEY = ~/.ec2/couchbase_aws-marketplace/pk-RPGT6DCSVXNK5QWMHAACI3KUHN5ILKOX.pem
EC2_CERT        = ~/.ec2/couchbase_aws-marketplace/cert-RPGT6DCSVXNK5QWMHAACI3KUHN5ILKOX.pem
EC2_ZONE        = us-east-1c
EC2_URL         = https://ec2.us-east-1.amazonaws.com
AMI_ID          = ami-7341831a

INSTANCE_TYPE = m1.xlarge
INSTANCE_HOST = `grep INSTANCE instance-describe.out | cut -f 4`
INSTANCE_ID   = `grep INSTANCE instance-describe.out | cut -f 2`

SSH_KEY = steveyen-key2
SSH_CMD = ssh -i ~/.ssh/$(SSH_KEY).pem ec2-user@$(INSTANCE_HOST)

IMAGE_NAME = membase-1.7.2_BasicAmazonLinux64-201109
IMAGE_DESC = pre-installed Membase Server 1.7.2, Enterprise Edition, 64bit

PKG_BASE = http://builds.hq.northscale.net/releases/1.7.2
PKG_NAME = membase-server-enterprise_x86_64_1.7.2r-20-g6604356.rpm
PKG_KIND = membase

SECURITY_GROUP = membase

VOLUME_ID = `grep VOLUME volume-describe.out | cut -f 2`
VOLUME_GB = 100

SNAPSHOT_ID = `grep SNAPSHOT snapshot-describe.out | cut -f 2`

image-create-step0: \
    instance-launch

image-create-step1: \
    instance-prep \
    instance-install-pkg \
    instance-install \
    volume-create \
    volume-attach \
    volume-mkfs \
    snapshot-create \
    volume-mount

image-create-step2: \
    instance-cleanse \
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
      --availability-zone $(EC2_ZONE) \
      --instance-type $(INSTANCE_TYPE) \
      --instance-initiated-shutdown-behavior stop \
      --group $(SECURITY_GROUP) \
      --key $(SSH_KEY) > instance-describe.out
	sleep 30
	$(MAKE) instance-describe

instance-describe:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-describe-instances $(INSTANCE_ID) > instance-describe.out

instance-prep:
	scp -i ~/.ssh/$(SSH_KEY).pem prep \
      ec2-user@$(INSTANCE_HOST):/home/ec2-user/prep
	$(SSH_CMD) -t sudo /home/ec2-user/prep

instance-install-pkg:
	$(SSH_CMD) wget -O $(PKG_NAME) $(PKG_BASE)/$(PKG_NAME)
	$(SSH_CMD) -t sudo rpm -i $(PKG_NAME)
	$(SSH_CMD) -t sudo /opt/$(PKG_KIND)/bin/mbenable-core-dumps.sh /tmp

instance-install:
	sed -e s,@@PKG_NAME@@,$(PKG_NAME),g README.txt.tmpl | \
      sed -e s,@@PKG_KIND@@,$(PKG_KIND),g > README.txt.out
	sed -e s,@@PKG_NAME@@,$(PKG_NAME),g config-pkg.tmpl | \
      sed -e s,@@PKG_KIND@@,$(PKG_KIND),g > config-pkg.out
	chmod a+x config-pkg.out
	scp -i ~/.ssh/$(SSH_KEY).pem README.txt.out \
      ec2-user@$(INSTANCE_HOST):/home/ec2-user/README.txt
	scp -i ~/.ssh/$(SSH_KEY).pem config-pkg.out \
      ec2-user@$(INSTANCE_HOST):/home/ec2-user/config-pkg
	$(SSH_CMD) "echo @reboot /home/ec2-user/config-pkg | crontab -"

instance-cleanse:
	$(SSH_CMD) rm -f \
      /home/ec2-user/.bash_history \
      /home/ec2-user/.ssh/authorized_keys \
      /home/ec2-user/*.tmp \
      /home/ec2-user/*~

instance-image-create:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-image \
      --name "$(IMAGE_NAME)" \
      --description "$(IMAGE_DESC)" \
      $(INSTANCE_ID)

volume-create:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-volume \
      --availability-zone $(EC2_ZONE) \
      --size $(VOLUME_GB) > volume-describe.out

volume-create-from-snapshot:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-volume \
      --availability-zone $(EC2_ZONE) \
      --size $(VOLUME_GB) \
      --snapshot $(SNAPSHOT_ID) > volume-describe.out

volume-describe:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-describe-volumes $(VOLUME_ID)

volume-attach:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-attach-volume $(VOLUME_ID) \
      --instance $(INSTANCE_ID) \
      --device /dev/sdh
	sleep 10

volume-mkfs:
	$(SSH_CMD) -t sudo mkfs.ext3 /dev/sdh

volume-mount:
	$(SSH_CMD) -t sudo mkdir -p /mnt
	$(SSH_CMD) -t sudo mkdir -m 000 /mnt/ebs
	$(SSH_CMD) -t "echo /dev/sdh /mnt/ebs ext3 noatime 0 0 | sudo tee -a /etc/fstab"
	$(SSH_CMD) -t sudo mount -a

snapshot-create:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-snapshot $(VOLUME_ID) \
      --description empty-ext3-$(VOLUME_GB)gb > snapshot-describe.out

clean:
	rm -f *.out

