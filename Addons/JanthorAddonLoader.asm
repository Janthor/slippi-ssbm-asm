################################################################################
# Address: 801a4c94
################################################################################
.include "Common/Common.s"
.include "Online/Online.s"

#Original Line
  stw	r3, -0x4F74 (r13)

backupall
  .set REG_FX_ARRAY, 31
  .set REG_MEX_DATA, 30

  #Check if file exists
  bl  FileName
  mflr  r3 # Addons.dat
  bl FN_CheckIfFileExists

  # Exit if file does not exist
  cmpwi r3, -1
  beq FileNotExist

    # Execute LoadRELDAT
  bl  FileName
  mflr  r3 # Addons.dat
  addi  r4,sp,0x80 # FXStructPointer
  bl  SymbolName # hkFunction
  mflr  r5
  bl LoadRELDAT_local # Standalone function LoadRELDAT
  mr REG_MEX_DATA, r4
  # Offsets from FXStructPointer
  # 0xC => pointer to fn table
    # 0x0 index first method
    # 0x0 offset address first method 
    # 0x1 index  method
    # 0x168 offset  method 
    # 0x2 index  method
    # 0x68 offset  method 

  # 0x10 => num of entries

  # Find offset to OnSceneChange:
  lwz REG_FX_ARRAY, 0x80(sp)
  lwz r3, 0xC(REG_MEX_DATA) # FX Table
  lwz r3, 0x0*4(r3) # Offset to OnSceneChange
  add r3, r3, REG_FX_ARRAY # offset from fx array to OnSceneChange
  mtctr r3
  bctrl 

restoreall
b EXIT

# args are
# r3 = file name
# r4 = array to store function pointers to
# r5 = symbol

# returns
# r3 = file data
LoadRELDAT_local:
.set  REG_FileName,31
.set  REG_Return,30
.set  REG_Symbol,29
.set  REG_FileSize,28
.set  REG_File,27
.set  REG_Header,26
.set  REG_mexData,25
.set Reloc,0x803d7074

backup
mr  REG_FileName,r3
mr  REG_Return,r4
mr  REG_Symbol,r5

#Load file
  mr r3, REG_FileName
  addi	r4, sp, 0x80
  mr r5, REG_Symbol
  li r6,0
  branchl	r12,0x80016c64
  mr REG_Header,r3
#Check if exists
  lwz  REG_mexData,0x80(sp)
  cmpwi REG_mexData,0
  beq mexPatch_Skip
#Reloc
  mr r3, REG_mexData
  branchl r12,Reloc
#Overload
  mr  r3,REG_mexData
  mr  r4,REG_Return
  bl  Overload


mexPatch_Skip:

#Flush instruction cache so code can be run from this file
  lwz  r3,0x20(REG_Header)   # file start
  lwz  r4,0x0(REG_Header)   # file size 
  branchl r12,0x80328f50

  mr r3,REG_Header
  mr r4,REG_mexData
  restore
  blr

###########################################

Overload:
# r3 = ftX
# r4 = table
#Copy function pointers - init
.set  ftX_FunctionRelocTable,0xC
.set  FunctionRelocTable_ReplaceThis,0x0
.set  FunctionRelocTable_ReplaceWith,0x4
.set  ftX_FunctionRelocTableCount,0x10
.set  REG_ftX,12
.set  REG_ThisElement,11
.set  REG_Code,10
.set  REG_OverloadTable,9
.set  REG_Count,8
.set  REG_RelocTable,7
  mr  REG_ftX,r3
  mr  REG_OverloadTable,r4
  lwz REG_RelocTable,ftX_FunctionRelocTable(REG_ftX)
  lwz REG_Code,0x0(REG_ftX)
  li  REG_Count,0
  b Overload_CheckLoop
Overload_Loop:
#Get this element
  mulli r3,REG_Count,8
  add REG_ThisElement,r3,REG_RelocTable

Overload_TableIndex:
#Get ram offset for this function
  lwz r3,FunctionRelocTable_ReplaceWith(REG_ThisElement)
  add r3,r3,REG_Code
#Update table
  lwz r4,FunctionRelocTable_ReplaceThis(REG_ThisElement)
  mulli r4,r4,4
  stwx  r3,r4,REG_OverloadTable
  b Overload_IncLoop

Overload_IncLoop:
  addi  REG_Count,REG_Count,1
Overload_CheckLoop:
  lwz r3,ftX_FunctionRelocTableCount(REG_ftX)
  cmpw  REG_Count,r3
  blt Overload_Loop
Overload_Exit:
  blr
############################################

# params: R3 = file string address
# returns R3 = -1 if not exists, 1 if exists
FN_CheckIfFileExists:
.set  REG_Buffer,31
.set  REG_FileString,30
.set  REG_FileLength,29
.set  REG_StringLength,28
.set  REG_BufferSize,27

# Init
backup

mr REG_FileString, r3 

# calculate string length
mr r3, REG_FileString
branchl r12, strlen
mr REG_StringLength, r3

# Alloc buffer
addi r3, REG_StringLength, 1
mr REG_BufferSize, r3 # store for later
branchl r12, HSD_MemAlloc
mr REG_Buffer, r3

# zero out bytes in buffer
# r3 here is REG_BUFFER still
mr r4, REG_BufferSize
branchl r12, Zero_AreaLength

# request game information from slippi
li r3, CONST_SlippiCmdFileLength        # store file length request ID
stb r3,0x0(REG_Buffer)
# copy file name to buffer
addi  r3,REG_Buffer,1
mr  r4,REG_FileString
branchl r12,strcpy
# Transfer buffer over DMA
addi  r4,REG_StringLength,2            #Buffer Length = strlen + command byte + \0
mr  r3,REG_Buffer        #Buffer Pointer
li  r5,CONST_ExiWrite
branchl r12,FN_EXITransferBuffer
GetFileLength_RECEIVE_DATA:
# Transfer buffer over DMA
mr  r3,REG_Buffer
li  r4,0x4               #Buffer Length
li  r5,CONST_ExiRead
branchl r12,FN_EXITransferBuffer
GetFileLength_CHECK_STATUS:
# Check if Slippi has a replacement file
lwz REG_FileLength,0x0(REG_Buffer)
cmpwi REG_FileLength,0
ble TransferFile_NO_REPLACEMENT

# Retun that there is a replacement
li r3, 1
b TransferFile_EXIT

TransferFile_NO_REPLACEMENT:
li r3, -1

TransferFile_EXIT:
restore
blr 



FileName:
blrl
.string "Addons.dat"
.align 2



SymbolName:
blrl
.string "hkFunction"
.align 2

FileNotExist:
restoreall
b EXIT

EXIT:

