################################################################################
# Address: 801a4c94
################################################################################
.include "Common/Common.s"
.include "Online/Online.s"

#Original Line
  stw	r3, -0x4F74 (r13)

backupall
  .set REG_FX_ARRAY, 31
  .set LoadRELDAT, 0x803d709c

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
  branchl r12, LoadRELDAT # Standalone function LoadRELDAT

  # Find offset to OnSceneChange:
  lwz REG_FX_ARRAY, 0x80(sp)
  mtctr REG_FX_ARRAY
  bctrl 

restoreall
b EXIT

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

