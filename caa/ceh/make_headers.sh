#!/bin/sh
#
# $Id$

f=CX_CH_EFW_INST.ceh
CLI=1
while test $CLI -le 4
do
   fout=`echo $f| sed -e "s=X=${CLI}="`
   echo "Writing $fout"
   cat $f|sed -e "s=XXX=${CLI}=" > $fout
   cat C${CLI}_CH_EFW_INST_CAV.ceh >> $fout
   CLI=$(($CLI+1))
done

flist="CX_CH_EFW_L2_P.ceh \
CX_CH_EFW_L3_P.ceh \
CX_CH_EFW_L2_E.ceh \
CX_CH_EFW_L3_E.ceh \
CX_CH_EFW_L3_DER.ceh"


for f in $flist
do
   CLI=1
   while test $CLI -le 4
   do
      fout=`echo $f| sed -e "s=X=${CLI}="`
      echo "Writing $fout"
      cat $f|sed -e "s=XXX=${CLI}=" > $fout
      CLI=$(($CLI+1))
   done
done
