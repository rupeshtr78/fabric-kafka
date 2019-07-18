################################################################################################################
#Kafka

# https://hyperledger-fabric.readthedocs.io/en/latest/kafka.html#steps:

# At a minimum, K should be set to 4. (As we will explain in Step 4 below, 
# this is the minimum number of nodes necessary in order to exhibit crash 
# fault tolerance, i.e. with 4 brokers, you can have 1 broker go down, all 
# channels will continue to be writeable and readable, and new channels 
# can be created.) Z will either be 3, 5, or 7. It has to be an odd number 
# to avoid split-brain scenarios, and larger than 1 in order to avoid 
# single point of failures. 
################################################################################################################
wget https://www.apache.org/dist/kafka/2.2.1/kafka_2.11-2.2.1.tgz

mkdir ~/kafka && cd ~/kafka

tar -xvzf ~/downloads/kafka_2.11-2.2.1.tgz --strip 1

# echo '1' > /home/fabric/zookeeper/myid
# echo '2' > /home/fabric/zookeeper/myid
# echo '3' > /home/fabric/zookeeper/myid

# Start on each node
kafka/bin/zookeeper-server-start.sh -daemon kafka/config/zookeeper.properties
kafka/bin/kafka-server-start.sh -daemon kafka/config/server.properties
# Stop on each node
kafka/bin/kafka-server-stop.sh
kafka/bin/zookeeper-server-stop.sh


# Verify also all brokers are registered to zookeeper:

kafka/bin/zookeeper-shell.sh 192.168.100.180:2181 ls /brokers/ids

# kafkat
kafkat brokers
kafkat partitions 
kafkat topics
################################################################################################################
#Fabric
################################################################################################################
bin/cryptogen generate --config=./crypto-config.yaml

bin/configtxgen -profile TwoOrgsOrdererGenesis -channelID rtr-sys-channel -outputBlock ./channel-artifacts/genesis.block

export CHANNEL_NAME=rtrchannel01
bin/configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP


# sudo mount u-nfs-serv:/opt/share/fabric-kafka   /opt/share/fabric-kafka
# cd /opt/share/fabric-kafka

# VM1- 
docker-compose -f docker-compose-orderer1.yaml up -d
# VM2- 
docker-compose -f docker-compose-orderer2.yaml up -d
# VM3- 
docker-compose -f docker-compose-orderer3.yaml up -d

# VM4- 
docker-compose -f docker-compose-peer0-org1.yaml up -d
# VM5- 
docker-compose -f docker-compose-peer1-org1.yaml up -d

# VM6- 
docker-compose -f docker-compose-peer0-org2.yaml up -d
# VM7- 
docker-compose -f docker-compose-peer1-org2.yaml up -d

################################################################################################################
#Channel
################################################################################################################
docker exec -it cli bash
export CHANNEL_NAME=rtrchannel01
peer channel create -o orderer1.fabric.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --outputBlock ./channel-artifacts/rtrchannel01.block --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem

# Join channel on each peer
peer channel join -b ./channel-artifacts/rtrchannel01.block

peer channel fetch newest -o orderer1.fabric.com:7050 -c $CHANNEL_NAME
peer channel join -b $CHANNEL_NAME_newest.block

# Channel update Org1
peer channel update -o orderer1.fabric.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/Org1MSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem
# Channel update Org2
peer channel update -o orderer1.fabric.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/Org2MSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem


################################################################################################################
#Chain Code
################################################################################################################
export CHANNEL_NAME=rtrchannel01
#Install on all peers
peer chaincode install -n rtrccex02 -v 1.0 -p github.com/chaincode/chaincode_example02/go
peer chaincode list --installed

peer chaincode instantiate -o orderer1.fabric.com:7050 -C $CHANNEL_NAME -n rtrccex02 -v 1.0 -c '{"Args":["init","a","100","b","200"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem -P "OR ('Org1MSP.peer','Org2MSP.peer')"
peer chaincode list --instantiated -C $CHANNEL_NAME 

peer chaincode invoke -o orderer1.fabric.com:7050 -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["invoke","a","b","10"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem

peer chaincode query -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["query","a"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem 60s

peer chaincode query -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["query","b"]}'
peer chaincode query -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["query","a"]}'

################################################################################################################
#zookeeper.properties
################################################################################################################
echo '3' > /home/hyper/logs/zookeeper/myid
#################################################################
 # the directory where the snapshot is stored.
dataDir=/home/hyper/logs/zookeeper
# the port at which the clients will connect
clientPort=2181
clientPortAddress=192.168.1.180
# disable the per-ip limit on the number of connections since this is a non-production config
maxClientCnxns=0
# The number of milliseconds of each tick
tickTime=2000
  
# The number of ticks that the initial synchronization phase can take
initLimit=10
  
# The number of ticks that can pass between 
# sending a request and getting an acknowledgement
syncLimit=5
 
# zoo servers
server.1=192.168.1.180:2888:3888
server.2=192.168.1.181:2888:3888
server.3=192.168.1.182:2888:3888
################################################################################################################

################################################################################################################
#kafka Commands
################################################################################################################

./kafka-topics.sh -zookeeper 192.168.1.180:2181 --list

./kafka-topics.sh --describe --zookeeper 192.168.1.180:2181

./kafka-console-consumer.sh -bootstrap-server 192.168.1.181:9092 --topic rtr-sys-channel

./bin/kafka-topics.sh --describe --topic rtrchannel01 --zookeeper 192.168.1.180:2181

################################################################################################################
#yahoo kafka Manager
################################################################################################################
./sbt clean dist

bin/kafka-manager -Dconfig.file=/home/hyper/kafka-manager/conf/application.conf -Dhttp.port=8080
################################################################################################################
http://192.168.1.180:8090

################################################################################################################
#Block Explorer
################################################################################################################
cd /opt/share/blockchain-explorer
docker-compose up -d

localhost-ip:8090




################################################################################################################
#Stop Services
################################################################################################################
docker-compose -f docker-compose-peer0-org1.yaml down -v
docker-compose -f docker-compose-peer1-org1.yaml down -v

docker-compose -f docker-compose-peer0-org2.yaml down -v
docker-compose -f docker-compose-peer1-org2.yaml down -v

docker-compose -f docker-compose-orderer1.yaml down -v
docker-compose -f docker-compose-orderer2.yaml down -v
docker-compose -f docker-compose-orderer3.yaml down -v

# Stop on each node
kafka/bin/kafka-server-stop.sh
kafka/bin/zookeeper-server-stop.sh


cd opt/share/fabric-kafka

################################################################################################################
#Marbles
################################################################################################################
# Install
peer chaincode install -n marbles -v 1 -p github.com/chaincode/marbles02/go


# Instantiate
peer chaincode instantiate -o orderer1.fabric.com:7050 -C $CHANNEL_NAME -n marbles -v 1 -c '{"Args":[""]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem -P "OR ('Org1MSP.peer','Org2MSP.peer')"

# ==== Invoke marbles ====
peer chaincode invoke -C $CHANNEL_NAME -n marbles -c '{"Args":["initMarble","marble1","blue","35","tom"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem
peer chaincode invoke -C $CHANNEL_NAME -n marbles -c '{"Args":["initMarble","marble2","red","50","tom"]}'  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem
peer chaincode invoke -C $CHANNEL_NAME -n marbles -c '{"Args":["initMarble","marble3","blue","70","tom"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem
peer chaincode invoke -C $CHANNEL_NAME -n marbles -c '{"Args":["transferMarble","marble2","jerry"]}'  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem
peer chaincode invoke -C $CHANNEL_NAME -n marbles -c '{"Args":["transferMarblesBasedOnColor","blue","jerry"]}'  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem
peer chaincode invoke -C $CHANNEL_NAME -n marbles -c '{"Args":["delete","marble1"]}'  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fabric.com/orderers/orderer1.fabric.com/msp/tlscacerts/tlsca.fabric.com-cert.pem

# ==== Query marbles ====
peer chaincode query -C $CHANNEL_NAME -n marbles -c '{"Args":["readMarble","marble1"]}'
peer chaincode query -C $CHANNEL_NAME -n marbles -c '{"Args":["getMarblesByRange","marble1","marble3"]}'
peer chaincode query -C $CHANNEL_NAME -n marbles -c '{"Args":["getHistoryForMarble","marble3"]}'



