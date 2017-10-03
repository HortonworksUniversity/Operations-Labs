#!/bin/bash

############################
# CREATE SECURITY CLUSTERS 
###########################


# 1. DEFINE VARIABLES
# 1.1 global vars 
export AWS_CLI_HOME=/usr/local/aws
PATH=$PATH:$AWS_CLI_HOME/bin
export AWS_ACCESS_KEY_ID=<your AWS access key id>
export AWS_SECRET_ACCESS_KEY=<your AWS access secret>

# 1.2 job specific variables -- change these as required 
export AWS_DEFAULT_REGION=us-west-2
export EC2_URL=https://ec2.us-west-2.amazonaws.com
export SEC_GROUP=<your aws security group id>
export AMI=ami-0e3fde6e
export AMI2=ami-b35346ca
export AMI3=ami-f8574281
export SUBNET=<your aws subnet id>
export TRAINING_NAME=Security-Cluster-Test
export FIRST_CLUSTER_LABEL=100
export NO_OF_VMs=1
export NO_OF_ADDTL_NODES=3
export INSTANCE_TYPE="m4.large"
export ADD_AD_SERVER=true
export ADD_XR_SERVER=true

# 1.3 Cloudformation variables -- do not change
export lab_prefix=$TRAINING_NAME"-"
export lab_first=$FIRST_CLUSTER_LABEL
export lab_count=$NO_OF_VMs
export lab_batch=$NO_OF_ADDTL_NODES
export cfn_parameters='
[
{"ParameterKey":"KeyName","ParameterValue":"training-keypair"},
{"ParameterKey":"AmbariServices","ParameterValue":"HDFS MAPREDUCE2 PIG YARN HIVE HBASE TEZ AMBARI_INFRA SLIDER ZOOKEEPER"},
{"ParameterKey":"HDPStack","ParameterValue":"2.6"},
{"ParameterKey":"AmbariVersion","ParameterValue":"2.5.2.0"},
{"ParameterKey":"AdditionalInstanceCount","ParameterValue":"'$NO_OF_ADDTL_NODES'"},
{"ParameterKey":"SubnetId","ParameterValue":"'$SUBNET'"},
{"ParameterKey":"SecurityGroups","ParameterValue":"'$SEC_GROUP'"},
{"ParameterKey":"InstanceType","ParameterValue":"'$INSTANCE_TYPE'"},
{"ParameterKey":"DeployCluster","ParameterValue":"true"}
]
'
#echo $cfn_parameters

# 1.4 cloudformation switches -- use next line to disable ROLLBACK (CloudFormation's auto-delete on error)
export cfn_switches="--disable-rollback"


# 2 Create Cloudformation instances 
echo "1. Creating new clusters in region $AWS_DEFAULT_REGION..."
echo "   This may take several minutes, please wait."
echo_file=`./clusters-create.sh`

# 2.1 create win AD Server instance if required
AD_SERVER_NAME=''
if [[ "$ADD_AD_SERVER" == "true" ]] ; then
   echo "   Creating Win-AD Instance"
   echo ""
   ADInstance=`aws ec2 run-instances --image-id $AMI --subnet-id $SUBNET --security-group-ids $SEC_GROUP --key-name training-keypair --instance-type m3.xlarge --count 1 | grep 'InstanceId' | awk -F':' '{print $2}' | sed 's|[ "]||g' | sed 's/,//'`
   AD_SERVER_NAME=$TRAINING_NAME"-WIN-AD-SERVER"
   aws ec2 create-tags --resources $ADInstance --tags Key=Name,Value=$AD_SERVER_NAME
fi
# 2.2 create cross-real authentication servers if required
if [[ "$ADD_XR_SERVER" == "true" ]] ; then
   echo "   Creating Cross-real auth MIT-KDC Server"
   echo ""
   ADInstance2=`aws ec2 run-instances --image-id $AMI2 --subnet-id $SUBNET --security-group-ids $SEC_GROUP --key-name training-keypair --instance-type m3.xlarge --count 1 | grep 'InstanceId' | awk -F':' '{print $2}' | sed 's|[ "]||g' | sed 's/,//'`
   AD_SERVER_NAME=$TRAINING_NAME"-MIT-KDC-XREALM"
   aws ec2 create-tags --resources $ADInstance2 --tags Key=Name,Value=$AD_SERVER_NAME
   echo "   Creating Cross-real auth AD Server"
   echo ""
   ADInstance3=`aws ec2 run-instances --image-id $AMI3 --subnet-id $SUBNET --security-group-ids $SEC_GROUP --key-name training-keypair --instance-type m3.xlarge --count 1 | grep 'InstanceId' | awk -F':' '{print $2}' | sed 's|[ "]||g' | sed 's/,//'`
   AD_SERVER_NAME=$TRAINING_NAME"-AD-XREALM"
   aws ec2 create-tags --resources $ADInstance3 --tags Key=Name,Value=$AD_SERVER_NAME
fi

# 3 PROCESS ALL CLUSTERS TO OBTAIN IPS  

# 3.1 get aws instance IDs 
my_instances=""
cluster_instance=$FIRST_CLUSTER_LABEL
for (( i=1; i<=$NO_OF_VMs; ++i )); do
  LONG_TRAINING_NAME=$TRAINING_NAME"-"$cluster_instance
  FLAG=""

# 3.1.1 wait for all clusters to be created before extracting IPs - there could be a pause of up to 300s between creation of each cluster
  while [ "$FLAG" != "CREATE_COMPLETE" ]; do
    FLAG=`aws cloudformation list-stack-resources --stack-name $LONG_TRAINING_NAME --output text | grep AdditionalNodes | cut -f5`
    sleep 20s
  done

# 3.1.2 aws commands 
  my_instances+=`aws cloudformation describe-stack-resource --stack-name $LONG_TRAINING_NAME --logical-resource-id AmbariNode --output json | grep PhysicalResourceId | awk -F':' '{print $2}' | sed 's|[ "]||g'`
  my_instances+=`aws autoscaling describe-auto-scaling-instances --no-paginate --output text | grep $LONG_TRAINING_NAME | cut -f5`
  my_instances=`echo "$my_instances" | tr '\n' ','`
  ((cluster_instance = $cluster_instance +1 ))

done
my_instances=`echo "$my_instances" | sed 's/,$//'`
my_instances=`echo "$my_instances" | sed 's/,/ /g'`
echo -e "2. List of newly created Instances:"
echo "$my_instances" 
echo ""

# 3.2 get internal/external IPs for cluster nodes
for instance in $my_instances
do
   temp_stack_name=`aws ec2 describe-instances --instance-ids $instance --output text | grep aws:cloudformation:stack-name | cut -f3`;
   temp_logical_id=`aws ec2 describe-instances --instance-ids $instance --output text | grep aws:cloudformation:logical-id | cut -f3`;
   if [[ $temp_logical_id = "AmbariNode" ]] ; then
      temp_logical_id="${temp_logical_id}-----";
   fi

   temp_public_ip=`aws ec2 describe-instances --instance-ids $instance --output text | grep INSTANCES | cut -f15`;
   temp_private_ip=`aws ec2 describe-instances --instance-ids $instance --output text | grep INSTANCES | cut -f13`;
   final_hosts+=$(echo "${my_instances2[$i]} : $temp_stack_name : $temp_logical_id : $temp_public_ip/$temp_private_ip | ");
done
echo -e "3. Final List of Hosts:\n"
final_hosts=`echo $final_hosts | sed 's/ | /\n/g' | cut -d':' -f2-4 | sed 's/|//' | sort -k 1`

if [[ "$ADD_AD_SERVER" == "true" ]] ; then
   temp_AD_public_ip=`aws ec2 describe-instances --instance-ids $ADInstance --output text | grep INSTANCES | cut -f16`;
   temp_AD_private_ip=`aws ec2 describe-instances --instance-ids $ADInstance --output text | grep INSTANCES | cut -f14`;
   final_hosts+=$(echo -e "\n ${TRAINING_NAME}     : WIN AD SERVER   : ${temp_AD_public_ip}/${temp_AD_private_ip} ");
fi

if [[ "$ADD_XR_SERVER" == "true" ]] ; then
   temp_AD_public_ip=`aws ec2 describe-instances --instance-ids $ADInstance2 --output text | grep INSTANCES | cut -f16`;
   temp_AD_private_ip=`aws ec2 describe-instances --instance-ids $ADInstance2 --output text | grep INSTANCES | cut -f14`;
   final_hosts+=$(echo -e "\n ${TRAINING_NAME}     : MIT-KDC-XREALM  : ${temp_AD_public_ip}/${temp_AD_private_ip} ");

   temp_AD_public_ip=`aws ec2 describe-instances --instance-ids $ADInstance --output text | grep INSTANCES | cut -f16`;
   temp_AD_private_ip=`aws ec2 describe-instances --instance-ids $ADInstance --output text | grep INSTANCES | cut -f14`;
   final_hosts+=$(echo -e "\n ${TRAINING_NAME}     : AD-XREALM       : ${temp_AD_public_ip}/${temp_AD_private_ip} ");
fi

echo "$final_hosts"
