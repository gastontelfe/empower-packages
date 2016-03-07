#!/bin/sh

# Copyright (c) 2013, Roberto Riggio
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   - Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   - Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#   - Neither the name of the CREATE-NET nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

BRIDGE=
MASTER_IP=
MASTER_PORT=
IFNAMES=
DEBUGFS=
VIRTUAL_IFNAME=
DEBUG="false"
STATIC=0
NO_STATS=0
NO_RX_STATS=0
NO_SIGNALLING_STATS=0

usage() {
    echo "Usage: $0 -o <BRIDGE> -a <MASTER_IP> -p <MASTER_PORT> -i <IFNAMES> -f <DEBUGFS> -v <VIRTUAL_IFNAME> [-d -s -r -c -b]"
    exit 1
}

while getopts "o:hsrcbda:p:i:f:v:" OPTVAL
do
    case $OPTVAL in
    o) BRIDGE="$OPTARG"
      ;;
    a) MASTER_IP="$OPTARG"
      ;;
    p) MASTER_PORT="$OPTARG"
      ;;
    i) IFNAMES="$OPTARG"
      ;;
    f) DEBUGFS="$OPTARG"
      ;;
    v) VIRTUAL_IFNAME="$OPTARG"
      ;;
    d) DEBUG="true"
      ;;
    s) STATIC=1
      ;;
    r) NO_RX_STATS=1
      ;;
    c) NO_STATS=1
      ;;
    b) NO_SIGNALLING_STATS=1
      ;;
    h) usage
      ;;
    esac
done

[ "$DEBUGFS" = "" -o "$MASTER_IP" = "" -o "$MASTER_PORT" = "" -o "$IFNAMES" = "" -o "$VIRTUAL_IFNAME" = "" ] && {
    usage
}

SUPPORTED_CHANNELS=""
CHANNELS=""
HWADDR=""

for IFNAME in $IFNAMES; do

	WIPHY=$(iw dev $IFNAME info | sed -n 's/^.*wiphy \([0-9]*\).*/\1/p')

	WIPHY_CHANNELS=$(iw phy phy$WIPHY info |  sed -n 's/^.* \([0-9]*\) MHz \[\([0-9]*\)\] ([0-9.]* dBm).*/\2/p')
	CHANNEL=$(iw dev $IFNAME info | sed -n 's/^.*channel \([0-9]*\) (\([0-9]*\) MHz).*/\1/p')
	BAND=$(iw dev $IFNAME info | sed -n 's/^.*channel \([0-9]*\) (\([0-9]*\) MHz), width: \([0-9]*\) MHz.*/\3/p')
	HWADDR=$(/sbin/ifconfig $IFNAME 2>&1 | sed -n 's/^.*HWaddr \([0-9A-Za-z\-]*\).*/\1/p' | sed -e 's/\-/:/g' | cut -c1-17)

	iw dev $IFNAME info | grep "no HT" -q && HT="" || HT="HT"

	for WIPHY_CHANNEL in $WIPHY_CHANNELS; do
		SUPPORTED_CHANNELS="$SUPPORTED_CHANNELS $WIPHY_CHANNEL/${HT}${BAND}"
	done
	
	CHANNELS="$CHANNELS $CHANNEL/${HT}${BAND}"
	
	HWADDRS="$HWADDRS $HWADDR"

done

WTP=$(/sbin/ifconfig $BRIDGE 2>&1 | sed -n 's/^.*HWaddr \([0-9A-Za-z\:]*\).*/\1/p')

UNIQUE=$(echo "$SUPPORTED_CHANNELS" | tr ' ' '\n' | sort -u -k2 | sort -n )
RE_STRING=""

for CHANNEL in $UNIQUE; do
	RE_STRING="$RE_STRING ${CHANNEL}"
	IDX=0
	for ACTIVE in $CHANNELS; do
		if [ $ACTIVE = $CHANNEL ]; then
			RE_STRING="${RE_STRING}/${IDX}"
		fi	
		IDX=$(($IDX+1))
	done
done

if [ "x$HT" != "x" ]; then

	echo """elementclass RateControl {
  \$rates,\$ht_rates|

  filter_tx :: FilterTX()

  input -> filter_tx -> output;"""

  if [ $STATIC == 0 ]; then

echo """  rate_control :: Minstrel(OFFSET 4, RT \$rates, RT_HT \$ht_rates);
  filter_tx [1] -> [1] rate_control [1] -> Discard();
  input [1] -> rate_control -> [1] output;"""

  else

echo """  rate_control :: SetTXRateHT(OFFSET 4, MCS 7);
  input [1] -> rate_control -> [1] output;"""

  fi

echo """
};

rates :: AvailableRates(DEFAULT 2 4 11 22 12 18 24 36 48 72 96 108);
rates_ht :: AvailableRates(DEFAULT 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15);
"""

else

	echo """elementclass RateControl {
  \$rates|

  filter_tx :: FilterTX()
  input -> filter_tx -> output;"""

  if [ $STATIC == 0 ]; then

echo """  rate_control :: Minstrel(OFFSET 4, RT \$rates);
  filter_tx [1] -> [1] rate_control [1] -> Discard();
  input [1] -> rate_control -> [1] output;"""

  else

echo """  rate_control :: SetTXRate(OFFSET 4, RATE 108);
  input [1] -> rate_control -> [1] output;"""

  fi

echo """
};

rates :: AvailableRates(DEFAULT 12 18 24 36 48 72 96 108);
"""

fi

echo """re :: EmpowerResourceElements($RE_STRING);

ControlSocket(\"TCP\", 7777);"""

if [ $NO_RX_STATS == 0 ]; then
  
  echo """ers :: EmpowerRXStats(EL el)

wifi_cl :: Classifier(0/08%0c,  // data
                      0/00%0c); // mgt

ers -> wifi_cl;"""

else

  echo """wifi_cl :: Classifier(0/08%0c,  // data
                      0/00%0c); // mgt"""

fi

echo """
switch_mngt :: PaintSwitch();
switch_data :: PaintSwitch();
"""

RCS=""
IDX=0
for IFNAME in $IFNAMES; do

	RCS="$RCS rc_$IDX/rate_control"
	FREQ=$(iw dev $IFNAME info | sed -n 's/^.*channel \([0-9]*\) (\([0-9]*\) MHz).*/\2/p')

	if [ "x$HT" != "x" ]; then
		echo "rc_$IDX :: RateControl(rates, rates_ht);"
	else
		echo "rc_$IDX :: RateControl(rates);"
	fi

	echo """
FromDevice($IFNAME, PROMISC false, OUTBOUND true, SNIFFER false)
  -> RadiotapDecap()
  -> FilterPhyErr()
  -> rc_$IDX
  -> WifiDupeFilter()
  -> Paint($IDX)"""

if [ $NO_RX_STATS == 0 ]; then
  echo """  -> ers;"""
else
  echo """  -> wifi_cl;"""
fi

echo """
sched_$IDX :: PrioSched()
  -> WifiSeq()
  -> [1] rc_$IDX [1]
  -> SetChannel(CHANNEL $FREQ)
  -> RadiotapEncap()
  -> ToDevice ($IFNAME);

switch_mngt[$IDX]
  -> Queue(50)
  -> [0] sched_$IDX;

switch_data[$IDX]
  -> Queue()
  -> [1] sched_$IDX;
"""

	IDX=$(($IDX+1))
done

echo """FromHost($VIRTUAL_IFNAME)
  -> wifi_encap :: EmpowerWifiEncap(EL el,"""

if [ $NO_STATS == 1 ]; then
	echo "                      NO_STATS true,"
fi

echo """                      DEBUG $DEBUG)
  -> switch_data;

ctrl :: Socket(TCP, $MASTER_IP, $MASTER_PORT, CLIENT true, VERBOSE true, RECONNECT_CALL el.reconnect)"""

if [ $NO_SIGNALLING_STATS == 0 ]; then
  echo """    -> downlink :: Counter()"""
fi

echo """    -> el :: EmpowerLVAPManager(HWADDRS \"$HWADDRS\",
                                WTP $WTP,
                                EBS ebs,
                                EAUTHR eauthr,
                                EASSOR eassor,
				RE re,
                                RCS \"$RCS\",
                                PERIOD 5000,
                                DEBUGFS \"$DEBUGFS\","""

if [ $NO_RX_STATS == 0 ]; then
  echo """                                ERS ers,"""
fi

if [ $NO_SIGNALLING_STATS == 0 ]; then
  echo """                                UPLINK uplink,"""
  echo """                                DOWNLINK downlink,"""
fi

echo """                                DEBUG $DEBUG)"""

if [ $NO_SIGNALLING_STATS == 0 ]; then
  echo """    -> uplink :: Counter()"""
fi

echo """    -> ctrl;

  wifi_cl [0]
    -> wifi_decap :: EmpowerWifiDecap(EL el,"""

if [ $NO_STATS == 1 ]; then
	echo "                      NO_STATS true,"
fi

echo """                        DEBUG $DEBUG)
    -> ToHost($VIRTUAL_IFNAME);

  wifi_decap [1] -> wifi_encap;

  wifi_cl [1]
    -> mgt_cl :: Classifier(0/40%f0,  // probe req
                            0/b0%f0,  // auth req
                            0/00%f0,  // assoc req
                            0/20%f0,  // reassoc req
                            0/c0%f0,  // deauth
                            0/a0%f0); // disassoc

  mgt_cl [0]
    -> ebs :: EmpowerBeaconSource(RT rates,"""
	[ "x$HT" != "x" ] && echo "                                  RT_HT rates_ht,"	

	echo """                                  EL el,
                                  PERIOD 100, 
                                  DEBUG $DEBUG)
    -> switch_mngt;

  mgt_cl [1]
    -> eauthr :: EmpowerOpenAuthResponder(EL el, DEBUG $DEBUG)
    -> switch_mngt;

  mgt_cl [2]
    -> eassor :: EmpowerAssociationResponder(RT rates,"""

	[ "x$HT" != "x" ] && echo "                                             RT_HT rates_ht,"	

	echo """                                             EL el,
                                             DEBUG $DEBUG)
    -> switch_mngt;

  mgt_cl [3]
    -> eassor;

  mgt_cl [4]
    -> EmpowerDeAuthResponder(EL el, DEBUG $DEBUG)
    -> Discard();

  mgt_cl [5]
    ->  EmpowerDisassocResponder(EL el, DEBUG $DEBUG)
    ->Discard();

"""

