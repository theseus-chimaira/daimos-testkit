; Standalone target test: assembler encoder -> native even-only decoder.
        .text
        .globl main
        .globl d6v037_encode_literals
        .globl d6v037_encode_cursor
main:
        movei   1,source
        movei   2,0200
        movei   3,encoded
        movei   4,0300
        pushj   17,d6v037_encode_literals
        jumpl   1,error_encode
        ; Compare full encoded output from both implementations.
        movem   1,length_a
        movei   1,source
        movei   2,0200
        movei   3,encoded_b
        movei   4,0300
        pushj   17,d6v037_encode_cursor
        jumpl   1,error_encode
        came    1,length_a
        jrst    error_data
        movei   5,0
compare_stream:
        camge   5,length_a
        jrst    compare_word
        jrst    compare_done
compare_word:
        move    6,encoded(5)
        came    6,encoded_b(5)
        jrst    error_data
        aoja    5,compare_stream
compare_done:
        setz    1,
        popj    17,
error_encode: movei 1,1
        popj 17,
error_decode: movei 1,2
        popj 17,
error_data: movei 1,3
        popj 17,
        .data
source:
        .word 0343326150103
        .word 0427227042316
        .word 067213333725
        .word 0344554264512
        .word 0262701035427
        .word 0351237771526
        .word 0777647126012
        .word 0131525774344
        .word 0437470700542
        .word 02343254725
        .word 06752350770
        .word 0404052012500
        .word 064154000127
        .word 0225376754541
        .word 0632746021706
        .word 0760470241542
        .word 0621506415603
        .word 0741422750372
        .word 0234362521327
        .word 0704155772
        .word 0244502074251
        .word 0345046207115
        .word 0304223104064
        .word 0605271407522
        .word 0632566255415
        .word 0505062765063
        .word 0430331155265
        .word 0142533757711
        .word 0453412666765
        .word 0454240132051
        .word 0376755645670
        .word 0373351077501
        .word 054575525025
        .word 0352144435263
        .word 0773053771155
        .word 0304126145002
        .word 034272622314
        .word 0367400467052
        .word 0547461011640
        .word 0332122047366
        .word 0245113035276
        .word 0340402437304
        .word 0661522435701
        .word 0401642661574
        .word 0723446042252
        .word 0612012330132
        .word 0520020523210
        .word 0200740314150
        .word 0264115256533
        .word 0423562743646
        .word 0412006377472
        .word 0504147746232
        .word 0156203503104
        .word 0530656024125
        .word 014523703126
        .word 0227655521224
        .word 0213035761321
        .word 0151620127553
        .word 0342213635430
        .word 0644633351031
        .word 0113062057227
        .word 024713675646
        .word 0176565753707
        .word 0441734567400
        .word 0457442207415
        .word 0373326557313
        .word 0415714144753
        .word 0605071061114
        .word 0410053641635
        .word 0755053023262
        .word 0417667550245
        .word 0511327020776
        .word 0262365604320
        .word 0267103126516
        .word 0627216764217
        .word 0577504605046
        .word 0272662777121
        .word 0642051124112
        .word 0337754743735
        .word 066177052624
        .word 0747742040341
        .word 0224461064436
        .word 051402465622
        .word 0372577732173
        .word 047147144031
        .word 0520651076601
        .word 0352506164773
        .word 0711666116276
        .word 0660066232224
        .word 0770557423422
        .word 0167141370372
        .word 0714741272132
        .word 0267032306573
        .word 0557430274337
        .word 0354064100156
        .word 0145571611673
        .word 063051245553
        .word 0546777340576
        .word 0724152436030
        .word 0554314652251
        .word 0267377706653
        .word 0410102044077
        .word 0200177143242
        .word 0230322376162
        .word 0704316005302
        .word 0647406622626
        .word 016322210337
        .word 0466064013246
        .word 0313613355405
        .word 0417622212463
        .word 0747356674714
        .word 0263403462766
        .word 0635423100402
        .word 0454776025425
        .word 0724346360662
        .word 0762662321344
        .word 0700760112623
        .word 0451046547072
        .word 050735255122
        .word 0212341456412
        .word 0422636656122
        .word 0107540102555
        .word 0443617362523
        .word 0454044455622
        .word 0606112576067
        .word 0112656551207
        .word 0342014053350
        .word 0676276573235
        .bss
encoded: .block 0300
encoded_b: .block 0300
length_a: .block 1
decoded: .block 0200
        .globl __test_exit
__test_exit: .block 1
