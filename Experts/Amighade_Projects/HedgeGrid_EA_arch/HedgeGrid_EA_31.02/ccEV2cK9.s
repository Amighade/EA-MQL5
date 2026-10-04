	.file	"strategy_tests.cpp"
	.text
#APP
	.globl _ZSt21ios_base_library_initv
#NO_APP
	.type	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, @function
_ZNSt17_Function_handlerIFvvEZ4mainEUlvE_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation:
.LFB5536:
	.cfi_startproc
	endbr64
	testl	%edx, %edx
	je	.L2
	cmpl	$1, %edx
	jne	.L4
	movq	%rsi, (%rdi)
	jmp	.L4
.L2:
	leaq	_ZTIZ4mainEUlvE_(%rip), %rax
	movq	%rax, (%rdi)
.L4:
	movl	$0, %eax
	ret
	.cfi_endproc
.LFE5536:
	.size	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, .-_ZNSt17_Function_handlerIFvvEZ4mainEUlvE_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation
	.type	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE0_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, @function
_ZNSt17_Function_handlerIFvvEZ4mainEUlvE0_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation:
.LFB5563:
	.cfi_startproc
	endbr64
	testl	%edx, %edx
	je	.L6
	cmpl	$1, %edx
	jne	.L8
	movq	%rsi, (%rdi)
	jmp	.L8
.L6:
	leaq	_ZTIZ4mainEUlvE0_(%rip), %rax
	movq	%rax, (%rdi)
.L8:
	movl	$0, %eax
	ret
	.cfi_endproc
.LFE5563:
	.size	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE0_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, .-_ZNSt17_Function_handlerIFvvEZ4mainEUlvE0_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation
	.type	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE1_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, @function
_ZNSt17_Function_handlerIFvvEZ4mainEUlvE1_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation:
.LFB5570:
	.cfi_startproc
	endbr64
	testl	%edx, %edx
	je	.L10
	cmpl	$1, %edx
	jne	.L12
	movq	%rsi, (%rdi)
	jmp	.L12
.L10:
	leaq	_ZTIZ4mainEUlvE1_(%rip), %rax
	movq	%rax, (%rdi)
.L12:
	movl	$0, %eax
	ret
	.cfi_endproc
.LFE5570:
	.size	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE1_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, .-_ZNSt17_Function_handlerIFvvEZ4mainEUlvE1_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation
	.type	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE2_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, @function
_ZNSt17_Function_handlerIFvvEZ4mainEUlvE2_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation:
.LFB5584:
	.cfi_startproc
	endbr64
	testl	%edx, %edx
	je	.L14
	cmpl	$1, %edx
	jne	.L16
	movq	%rsi, (%rdi)
	jmp	.L16
.L14:
	leaq	_ZTIZ4mainEUlvE2_(%rip), %rax
	movq	%rax, (%rdi)
.L16:
	movl	$0, %eax
	ret
	.cfi_endproc
.LFE5584:
	.size	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE2_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation, .-_ZNSt17_Function_handlerIFvvEZ4mainEUlvE2_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation
	.section	.text._ZNSt6vectorImSaImEED2Ev,"axG",@progbits,_ZNSt6vectorImSaImEED5Ev,comdat
	.align 2
	.weak	_ZNSt6vectorImSaImEED2Ev
	.type	_ZNSt6vectorImSaImEED2Ev, @function
_ZNSt6vectorImSaImEED2Ev:
.LFB6517:
	.cfi_startproc
	endbr64
	movq	(%rdi), %rax
	testq	%rax, %rax
	je	.L20
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	16(%rdi), %rsi
	subq	%rax, %rsi
	movq	%rax, %rdi
	call	_ZdlPvm@PLT
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
.L20:
	ret
	.cfi_endproc
.LFE6517:
	.size	_ZNSt6vectorImSaImEED2Ev, .-_ZNSt6vectorImSaImEED2Ev
	.weak	_ZNSt6vectorImSaImEED1Ev
	.set	_ZNSt6vectorImSaImEED1Ev,_ZNSt6vectorImSaImEED2Ev
	.section	.text._ZNSt6vectorI8PositionSaIS0_EED2Ev,"axG",@progbits,_ZNSt6vectorI8PositionSaIS0_EED5Ev,comdat
	.align 2
	.weak	_ZNSt6vectorI8PositionSaIS0_EED2Ev
	.type	_ZNSt6vectorI8PositionSaIS0_EED2Ev, @function
_ZNSt6vectorI8PositionSaIS0_EED2Ev:
.LFB6508:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movq	%rdi, %r12
	movq	8(%rdi), %rbp
	movq	(%rdi), %rbx
	cmpq	%rbx, %rbp
	jne	.L26
.L24:
	movq	(%r12), %rdi
	testq	%rdi, %rdi
	je	.L23
	movq	16(%r12), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L23:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L25:
	.cfi_restore_state
	addq	$96, %rbx
	cmpq	%rbx, %rbp
	je	.L24
.L26:
	movq	56(%rbx), %rdi
	leaq	72(%rbx), %rax
	cmpq	%rax, %rdi
	je	.L25
	movq	72(%rbx), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L25
	.cfi_endproc
.LFE6508:
	.size	_ZNSt6vectorI8PositionSaIS0_EED2Ev, .-_ZNSt6vectorI8PositionSaIS0_EED2Ev
	.weak	_ZNSt6vectorI8PositionSaIS0_EED1Ev
	.set	_ZNSt6vectorI8PositionSaIS0_EED1Ev,_ZNSt6vectorI8PositionSaIS0_EED2Ev
	.section	.text._ZNSt6vectorI15TransactionItemSaIS0_EED2Ev,"axG",@progbits,_ZNSt6vectorI15TransactionItemSaIS0_EED5Ev,comdat
	.align 2
	.weak	_ZNSt6vectorI15TransactionItemSaIS0_EED2Ev
	.type	_ZNSt6vectorI15TransactionItemSaIS0_EED2Ev, @function
_ZNSt6vectorI15TransactionItemSaIS0_EED2Ev:
.LFB6520:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movq	%rdi, %r12
	movq	8(%rdi), %rbp
	movq	(%rdi), %rbx
	cmpq	%rbx, %rbp
	jne	.L33
.L31:
	movq	(%r12), %rdi
	testq	%rdi, %rdi
	je	.L30
	movq	16(%r12), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L30:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L32:
	.cfi_restore_state
	addq	$120, %rbx
	cmpq	%rbx, %rbp
	je	.L31
.L33:
	movq	8(%rbx), %rdi
	leaq	24(%rbx), %rax
	cmpq	%rax, %rdi
	je	.L32
	movq	24(%rbx), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L32
	.cfi_endproc
.LFE6520:
	.size	_ZNSt6vectorI15TransactionItemSaIS0_EED2Ev, .-_ZNSt6vectorI15TransactionItemSaIS0_EED2Ev
	.weak	_ZNSt6vectorI15TransactionItemSaIS0_EED1Ev
	.set	_ZNSt6vectorI15TransactionItemSaIS0_EED1Ev,_ZNSt6vectorI15TransactionItemSaIS0_EED2Ev
	.section	.text._ZNSt6vectorI5OrderSaIS0_EED2Ev,"axG",@progbits,_ZNSt6vectorI5OrderSaIS0_EED5Ev,comdat
	.align 2
	.weak	_ZNSt6vectorI5OrderSaIS0_EED2Ev
	.type	_ZNSt6vectorI5OrderSaIS0_EED2Ev, @function
_ZNSt6vectorI5OrderSaIS0_EED2Ev:
.LFB6505:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movq	%rdi, %r12
	movq	8(%rdi), %rbp
	movq	(%rdi), %rbx
	cmpq	%rbx, %rbp
	jne	.L40
.L38:
	movq	(%r12), %rdi
	testq	%rdi, %rdi
	je	.L37
	movq	16(%r12), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L37:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L39:
	.cfi_restore_state
	addq	$112, %rbx
	cmpq	%rbx, %rbp
	je	.L38
.L40:
	movq	64(%rbx), %rdi
	leaq	80(%rbx), %rax
	cmpq	%rax, %rdi
	je	.L39
	movq	80(%rbx), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L39
	.cfi_endproc
.LFE6505:
	.size	_ZNSt6vectorI5OrderSaIS0_EED2Ev, .-_ZNSt6vectorI5OrderSaIS0_EED2Ev
	.weak	_ZNSt6vectorI5OrderSaIS0_EED1Ev
	.set	_ZNSt6vectorI5OrderSaIS0_EED1Ev,_ZNSt6vectorI5OrderSaIS0_EED2Ev
	.section	.text._ZNSt6vectorI15MqlTradeRequestSaIS0_EED2Ev,"axG",@progbits,_ZNSt6vectorI15MqlTradeRequestSaIS0_EED5Ev,comdat
	.align 2
	.weak	_ZNSt6vectorI15MqlTradeRequestSaIS0_EED2Ev
	.type	_ZNSt6vectorI15MqlTradeRequestSaIS0_EED2Ev, @function
_ZNSt6vectorI15MqlTradeRequestSaIS0_EED2Ev:
.LFB6511:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movq	%rdi, %r12
	movq	8(%rdi), %rbp
	movq	(%rdi), %rbx
	cmpq	%rbx, %rbp
	jne	.L47
.L45:
	movq	(%r12), %rdi
	testq	%rdi, %rdi
	je	.L44
	movq	16(%r12), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L44:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L46:
	.cfi_restore_state
	addq	$112, %rbx
	cmpq	%rbx, %rbp
	je	.L45
.L47:
	movq	(%rbx), %rdi
	leaq	16(%rbx), %rax
	cmpq	%rax, %rdi
	je	.L46
	movq	16(%rbx), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L46
	.cfi_endproc
.LFE6511:
	.size	_ZNSt6vectorI15MqlTradeRequestSaIS0_EED2Ev, .-_ZNSt6vectorI15MqlTradeRequestSaIS0_EED2Ev
	.weak	_ZNSt6vectorI15MqlTradeRequestSaIS0_EED1Ev
	.set	_ZNSt6vectorI15MqlTradeRequestSaIS0_EED1Ev,_ZNSt6vectorI15MqlTradeRequestSaIS0_EED2Ev
	.section	.text._ZNSt6vectorI10SubmissionSaIS0_EED2Ev,"axG",@progbits,_ZNSt6vectorI10SubmissionSaIS0_EED5Ev,comdat
	.align 2
	.weak	_ZNSt6vectorI10SubmissionSaIS0_EED2Ev
	.type	_ZNSt6vectorI10SubmissionSaIS0_EED2Ev, @function
_ZNSt6vectorI10SubmissionSaIS0_EED2Ev:
.LFB6514:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movq	%rdi, %r12
	movq	8(%rdi), %rbp
	movq	(%rdi), %rbx
	cmpq	%rbx, %rbp
	jne	.L54
.L52:
	movq	(%r12), %rdi
	testq	%rdi, %rdi
	je	.L51
	movq	16(%r12), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L51:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L53:
	.cfi_restore_state
	addq	$144, %rbx
	cmpq	%rbx, %rbp
	je	.L52
.L54:
	movq	(%rbx), %rdi
	leaq	16(%rbx), %rax
	cmpq	%rax, %rdi
	je	.L53
	movq	16(%rbx), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L53
	.cfi_endproc
.LFE6514:
	.size	_ZNSt6vectorI10SubmissionSaIS0_EED2Ev, .-_ZNSt6vectorI10SubmissionSaIS0_EED2Ev
	.weak	_ZNSt6vectorI10SubmissionSaIS0_EED1Ev
	.set	_ZNSt6vectorI10SubmissionSaIS0_EED1Ev,_ZNSt6vectorI10SubmissionSaIS0_EED2Ev
	.section	.text._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev,"axG",@progbits,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED5Ev,comdat
	.align 2
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev
	.type	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev, @function
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev:
.LFB4784:
	.cfi_startproc
	endbr64
	movq	(%rdi), %rax
	leaq	16(%rdi), %rdx
	cmpq	%rdx, %rax
	je	.L61
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	16(%rdi), %rsi
	addq	$1, %rsi
	movq	%rax, %rdi
	call	_ZdlPvm@PLT
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
.L61:
	ret
	.cfi_endproc
.LFE4784:
	.size	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev, .-_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED1Ev
	.set	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED1Ev,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev
	.section	.text._ZN9GridStateD2Ev,"axG",@progbits,_ZN9GridStateD5Ev,comdat
	.align 2
	.weak	_ZN9GridStateD2Ev
	.type	_ZN9GridStateD2Ev, @function
_ZN9GridStateD2Ev:
.LFB4586:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	movq	408(%rdi), %rdi
	leaq	424(%rbx), %rax
	cmpq	%rax, %rdi
	je	.L65
	movq	424(%rbx), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L65:
	movq	376(%rbx), %rdi
	leaq	392(%rbx), %rax
	cmpq	%rax, %rdi
	je	.L66
	movq	392(%rbx), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L66:
	movq	248(%rbx), %rdi
	testq	%rdi, %rdi
	je	.L67
	movq	264(%rbx), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L67:
	movq	224(%rbx), %rdi
	testq	%rdi, %rdi
	je	.L68
	movq	240(%rbx), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L68:
	movq	200(%rbx), %rdi
	testq	%rdi, %rdi
	je	.L69
	movq	216(%rbx), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L69:
	movq	176(%rbx), %rdi
	testq	%rdi, %rdi
	je	.L70
	movq	192(%rbx), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L70:
	movq	152(%rbx), %rdi
	testq	%rdi, %rdi
	je	.L71
	movq	168(%rbx), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L71:
	movq	8(%rbx), %rdi
	testq	%rdi, %rdi
	je	.L64
	movq	24(%rbx), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L64:
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE4586:
	.size	_ZN9GridStateD2Ev, .-_ZN9GridStateD2Ev
	.weak	_ZN9GridStateD1Ev
	.set	_ZN9GridStateD1Ev,_ZN9GridStateD2Ev
	.text
	.globl	_Z14GetTickCount64v
	.type	_Z14GetTickCount64v, @function
_Z14GetTickCount64v:
.LFB3718:
	.cfi_startproc
	endbr64
	movq	mock_ms(%rip), %rax
	ret
	.cfi_endproc
.LFE3718:
	.size	_Z14GetTickCount64v, .-_Z14GetTickCount64v
	.globl	_Z19GetMicrosecondCountv
	.type	_Z19GetMicrosecondCountv, @function
_Z19GetMicrosecondCountv:
.LFB3719:
	.cfi_startproc
	endbr64
	movq	mock_us(%rip), %rax
	leaq	1(%rax), %rdx
	movq	%rdx, mock_us(%rip)
	ret
	.cfi_endproc
.LFE3719:
	.size	_Z19GetMicrosecondCountv, .-_Z19GetMicrosecondCountv
	.globl	_Z14ResetLastErrorv
	.type	_Z14ResetLastErrorv, @function
_Z14ResetLastErrorv:
.LFB3720:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc
.LFE3720:
	.size	_Z14ResetLastErrorv, .-_Z14ResetLastErrorv
	.globl	_Z12GetLastErrorv
	.type	_Z12GetLastErrorv, @function
_Z12GetLastErrorv:
.LFB3721:
	.cfi_startproc
	endbr64
	cmpb	$1, sendOK(%rip)
	sbbl	%eax, %eax
	andl	$999, %eax
	ret
	.cfi_endproc
.LFE3721:
	.size	_Z12GetLastErrorv, .-_Z12GetLastErrorv
	.globl	_Z7MathAbsd
	.type	_Z7MathAbsd, @function
_Z7MathAbsd:
.LFB3727:
	.cfi_startproc
	endbr64
	andpd	.LC0(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3727:
	.size	_Z7MathAbsd, .-_Z7MathAbsd
	.globl	_Z8MathCeild
	.type	_Z8MathCeild, @function
_Z8MathCeild:
.LFB3728:
	.cfi_startproc
	endbr64
	movapd	%xmm0, %xmm3
	movsd	.LC3(%rip), %xmm2
	movapd	%xmm0, %xmm1
	andpd	%xmm2, %xmm1
	movsd	.LC1(%rip), %xmm4
	ucomisd	%xmm1, %xmm4
	jbe	.L82
	cvttsd2siq	%xmm0, %rax
	pxor	%xmm1, %xmm1
	cvtsi2sdq	%rax, %xmm1
	cmpnlesd	%xmm1, %xmm3
	movsd	.LC2(%rip), %xmm4
	andpd	%xmm4, %xmm3
	addsd	%xmm1, %xmm3
	andnpd	%xmm0, %xmm2
	orpd	%xmm2, %xmm3
.L82:
	movapd	%xmm3, %xmm0
	ret
	.cfi_endproc
.LFE3728:
	.size	_Z8MathCeild, .-_Z8MathCeild
	.globl	_Z9MathFloord
	.type	_Z9MathFloord, @function
_Z9MathFloord:
.LFB3729:
	.cfi_startproc
	endbr64
	movapd	%xmm0, %xmm3
	movsd	.LC3(%rip), %xmm2
	movapd	%xmm0, %xmm1
	andpd	%xmm2, %xmm1
	movsd	.LC1(%rip), %xmm4
	ucomisd	%xmm1, %xmm4
	jbe	.L84
	cvttsd2siq	%xmm0, %rax
	pxor	%xmm1, %xmm1
	cvtsi2sdq	%rax, %xmm1
	movapd	%xmm1, %xmm3
	cmpnlesd	%xmm0, %xmm3
	movsd	.LC2(%rip), %xmm4
	andpd	%xmm4, %xmm3
	subsd	%xmm3, %xmm1
	andnpd	%xmm0, %xmm2
	movapd	%xmm1, %xmm3
	orpd	%xmm2, %xmm3
.L84:
	movapd	%xmm3, %xmm0
	ret
	.cfi_endproc
.LFE3729:
	.size	_Z9MathFloord, .-_Z9MathFloord
	.globl	_Z9MathRoundd
	.type	_Z9MathRoundd, @function
_Z9MathRoundd:
.LFB3730:
	.cfi_startproc
	endbr64
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	call	round@PLT
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3730:
	.size	_Z9MathRoundd, .-_Z9MathRoundd
	.globl	_Z7MathPowdd
	.type	_Z7MathPowdd, @function
_Z7MathPowdd:
.LFB3731:
	.cfi_startproc
	endbr64
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	call	pow@PLT
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3731:
	.size	_Z7MathPowdd, .-_Z7MathPowdd
	.globl	_Z15NormalizeDoubledi
	.type	_Z15NormalizeDoubledi, @function
_Z15NormalizeDoubledi:
.LFB3732:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc
.LFE3732:
	.size	_Z15NormalizeDoubledi, .-_Z15NormalizeDoubledi
	.globl	_Z19TerminalInfoIntegeri
	.type	_Z19TerminalInfoIntegeri, @function
_Z19TerminalInfoIntegeri:
.LFB3733:
	.cfi_startproc
	endbr64
	cmpl	$111, %edi
	je	.L93
	movzbl	tradeAllowed(%rip), %eax
	ret
.L93:
	movzbl	connected(%rip), %eax
	ret
	.cfi_endproc
.LFE3733:
	.size	_Z19TerminalInfoIntegeri, .-_Z19TerminalInfoIntegeri
	.globl	_Z14MQLInfoIntegeri
	.type	_Z14MQLInfoIntegeri, @function
_Z14MQLInfoIntegeri:
.LFB3734:
	.cfi_startproc
	endbr64
	movzbl	tradeAllowed(%rip), %eax
	ret
	.cfi_endproc
.LFE3734:
	.size	_Z14MQLInfoIntegeri, .-_Z14MQLInfoIntegeri
	.globl	_Z18AccountInfoIntegeri
	.type	_Z18AccountInfoIntegeri, @function
_Z18AccountInfoIntegeri:
.LFB3735:
	.cfi_startproc
	endbr64
	cmpl	$114, %edi
	je	.L96
	movzbl	fifo(%rip), %eax
	ret
.L96:
	movq	accountMode(%rip), %rax
	ret
	.cfi_endproc
.LFE3735:
	.size	_Z18AccountInfoIntegeri, .-_Z18AccountInfoIntegeri
	.globl	_Z17AccountInfoDoublei
	.type	_Z17AccountInfoDoublei, @function
_Z17AccountInfoDoublei:
.LFB3736:
	.cfi_startproc
	endbr64
	movsd	.LC4(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3736:
	.size	_Z17AccountInfoDoublei, .-_Z17AccountInfoDoublei
	.globl	_Z14PositionsTotalv
	.type	_Z14PositionsTotalv, @function
_Z14PositionsTotalv:
.LFB3737:
	.cfi_startproc
	endbr64
	movq	8+positions(%rip), %rax
	subq	positions(%rip), %rax
	sarq	$5, %rax
	imull	$-1431655765, %eax, %eax
	ret
	.cfi_endproc
.LFE3737:
	.size	_Z14PositionsTotalv, .-_Z14PositionsTotalv
	.globl	_Z11OrdersTotalv
	.type	_Z11OrdersTotalv, @function
_Z11OrdersTotalv:
.LFB3738:
	.cfi_startproc
	endbr64
	movq	8+orders(%rip), %rax
	subq	orders(%rip), %rax
	sarq	$4, %rax
	imull	$-1227133513, %eax, %eax
	ret
	.cfi_endproc
.LFE3738:
	.size	_Z11OrdersTotalv, .-_Z11OrdersTotalv
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC5:
	.string	"__n < this->size()"
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align 8
.LC6:
	.string	"std::vector<_Tp, _Alloc>::reference std::vector<_Tp, _Alloc>::operator[](size_type) [with _Tp = Position; _Alloc = std::allocator<Position>; reference = Position&; size_type = long unsigned int]"
	.align 8
.LC7:
	.string	"/usr/include/c++/13/bits/stl_vector.h"
	.text
	.globl	_Z17PositionGetTicketi
	.type	_Z17PositionGetTicketi, @function
_Z17PositionGetTicketi:
.LFB3739:
	.cfi_startproc
	endbr64
	movl	%edi, selectedPosition(%rip)
	testl	%edi, %edi
	js	.L104
	movq	positions(%rip), %rcx
	movq	8+positions(%rip), %rax
	subq	%rcx, %rax
	sarq	$5, %rax
	movabsq	$-6148914691236517205, %rdx
	imulq	%rdx, %rax
	movl	$0, %edx
	cmpl	%eax, %edi
	jge	.L101
	movslq	%edi, %rdi
	cmpq	%rax, %rdi
	jnb	.L109
	leaq	(%rdi,%rdi,2), %rax
	salq	$5, %rax
	movq	(%rcx,%rax), %rdx
	jmp	.L101
.L109:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC6(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L104:
	.cfi_def_cfa_offset 8
	movl	$0, %edx
.L101:
	movq	%rdx, %rax
	ret
	.cfi_endproc
.LFE3739:
	.size	_Z17PositionGetTicketi, .-_Z17PositionGetTicketi
	.globl	_Z22PositionSelectByTicketm
	.type	_Z22PositionSelectByTicketm, @function
_Z22PositionSelectByTicketm:
.LFB3740:
	.cfi_startproc
	endbr64
	movq	positions(%rip), %rdx
	movq	8+positions(%rip), %rcx
	subq	%rdx, %rcx
	sarq	$5, %rcx
	movabsq	$-6148914691236517205, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L115
	leal	-1(%rcx), %r8d
	movl	$0, %eax
	jmp	.L114
.L116:
	movq	%rsi, %rax
.L114:
	cmpq	%rax, %rcx
	je	.L120
	cmpq	%rdi, (%rdx)
	je	.L121
	leaq	1(%rax), %rsi
	addq	$96, %rdx
	cmpq	%rax, %r8
	jne	.L116
	movl	$-1, %eax
	movl	$0, %edx
	jmp	.L111
.L120:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC6(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L121:
	.cfi_def_cfa_offset 8
	movl	$1, %edx
.L111:
	movl	%eax, selectedPosition(%rip)
	movl	%edx, %eax
	ret
.L115:
	movl	$-1, %eax
	movl	$0, %edx
	jmp	.L111
	.cfi_endproc
.LFE3740:
	.size	_Z22PositionSelectByTicketm, .-_Z22PositionSelectByTicketm
	.section	.rodata.str1.8
	.align 8
.LC8:
	.string	"std::vector<_Tp, _Alloc>::reference std::vector<_Tp, _Alloc>::operator[](size_type) [with _Tp = Order; _Alloc = std::allocator<Order>; reference = Order&; size_type = long unsigned int]"
	.text
	.globl	_Z14OrderGetTicketi
	.type	_Z14OrderGetTicketi, @function
_Z14OrderGetTicketi:
.LFB3750:
	.cfi_startproc
	endbr64
	movl	%edi, selectedOrder(%rip)
	testl	%edi, %edi
	js	.L125
	movq	orders(%rip), %rcx
	movq	8+orders(%rip), %rax
	subq	%rcx, %rax
	sarq	$4, %rax
	movabsq	$7905747460161236407, %rdx
	imulq	%rdx, %rax
	movl	$0, %edx
	cmpl	%eax, %edi
	jge	.L122
	movslq	%edi, %rdi
	cmpq	%rax, %rdi
	jnb	.L130
	leaq	0(,%rdi,8), %rax
	subq	%rdi, %rax
	salq	$4, %rax
	movq	(%rcx,%rax), %rdx
	jmp	.L122
.L130:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC8(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L125:
	.cfi_def_cfa_offset 8
	movl	$0, %edx
.L122:
	movq	%rdx, %rax
	ret
	.cfi_endproc
.LFE3750:
	.size	_Z14OrderGetTicketi, .-_Z14OrderGetTicketi
	.globl	_Z11OrderSelectm
	.type	_Z11OrderSelectm, @function
_Z11OrderSelectm:
.LFB3751:
	.cfi_startproc
	endbr64
	movq	orders(%rip), %rdx
	movq	8+orders(%rip), %rcx
	subq	%rdx, %rcx
	sarq	$4, %rcx
	movabsq	$7905747460161236407, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L136
	leal	-1(%rcx), %r8d
	movl	$0, %eax
	jmp	.L135
.L137:
	movq	%rsi, %rax
.L135:
	cmpq	%rax, %rcx
	je	.L141
	cmpq	%rdi, (%rdx)
	je	.L142
	leaq	1(%rax), %rsi
	addq	$112, %rdx
	cmpq	%rax, %r8
	jne	.L137
	movl	$-1, %eax
	movl	$0, %edx
	jmp	.L132
.L141:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC8(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L142:
	.cfi_def_cfa_offset 8
	movl	$1, %edx
.L132:
	movl	%eax, selectedOrder(%rip)
	movl	%edx, %eax
	ret
.L136:
	movl	$-1, %eax
	movl	$0, %edx
	jmp	.L132
	.cfi_endproc
.LFE3751:
	.size	_Z11OrderSelectm, .-_Z11OrderSelectm
	.globl	_Z17HistoryDealSelectm
	.type	_Z17HistoryDealSelectm, @function
_Z17HistoryDealSelectm:
.LFB3764:
	.cfi_startproc
	endbr64
	movq	16+historyDeals(%rip), %rax
	leaq	8+historyDeals(%rip), %rdx
	testq	%rax, %rax
	jne	.L147
	jmp	.L144
.L145:
	movq	24(%rax), %rax
.L146:
	testq	%rax, %rax
	je	.L150
.L147:
	cmpq	%rdi, 32(%rax)
	jb	.L145
	movq	%rax, %rdx
	movq	16(%rax), %rax
	jmp	.L146
.L150:
	leaq	8+historyDeals(%rip), %rax
	cmpq	%rax, %rdx
	je	.L144
	cmpq	32(%rdx), %rdi
	jnb	.L144
	movq	%rax, %rdx
.L144:
	leaq	8+historyDeals(%rip), %rax
	cmpq	%rax, %rdx
	setne	%al
	ret
	.cfi_endproc
.LFE3764:
	.size	_Z17HistoryDealSelectm, .-_Z17HistoryDealSelectm
	.globl	_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEiRl
	.type	_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEiRl, @function
_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEiRl:
.LFB3774:
	.cfi_startproc
	endbr64
	cmpl	$101, %esi
	sete	%al
	movzbl	%al, %eax
	addq	%rax, %rax
	movq	%rax, (%rdx)
	movl	$1, %eax
	ret
	.cfi_endproc
.LFE3774:
	.size	_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEiRl, .-_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEiRl
	.globl	_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	.type	_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi, @function
_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi:
.LFB3775:
	.cfi_startproc
	endbr64
	movl	$0, %eax
	ret
	.cfi_endproc
.LFE3775:
	.size	_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi, .-_Z17SymbolInfoIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	.globl	_Z16SymbolInfoDoubleNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	.type	_Z16SymbolInfoDoubleNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi, @function
_Z16SymbolInfoDoubleNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi:
.LFB3776:
	.cfi_startproc
	endbr64
	subl	$101, %esi
	cmpl	$6, %esi
	ja	.L154
	movl	%esi, %esi
	leaq	.L156(%rip), %rdx
	movslq	(%rdx,%rsi,4), %rax
	addq	%rdx, %rax
	notrack jmp	*%rax
	.section	.rodata
	.align 4
	.align 4
.L156:
	.long	.L161-.L156
	.long	.L160-.L156
	.long	.L159-.L156
	.long	.L158-.L156
	.long	.L161-.L156
	.long	.L161-.L156
	.long	.L155-.L156
	.text
.L154:
	pxor	%xmm0, %xmm0
	ret
.L160:
	movsd	.LC10(%rip), %xmm0
	ret
.L159:
	movsd	.LC11(%rip), %xmm0
	ret
.L158:
	movsd	.LC2(%rip), %xmm0
	ret
.L155:
	movsd	.LC10(%rip), %xmm0
	ret
.L161:
	movsd	.LC9(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3776:
	.size	_Z16SymbolInfoDoubleNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi, .-_Z16SymbolInfoDoubleNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	.globl	_Z14SymbolInfoTickNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEER7MqlTick
	.type	_Z14SymbolInfoTickNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEER7MqlTick, @function
_Z14SymbolInfoTickNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEER7MqlTick:
.LFB3777:
	.cfi_startproc
	endbr64
	movq	.LC10(%rip), %rax
	movq	%rax, (%rsi)
	movq	.LC11(%rip), %rax
	movq	%rax, 8(%rsi)
	movl	$1, %eax
	ret
	.cfi_endproc
.LFE3777:
	.size	_Z14SymbolInfoTickNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEER7MqlTick, .-_Z14SymbolInfoTickNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEER7MqlTick
	.globl	_Z24EventSetMillisecondTimeri
	.type	_Z24EventSetMillisecondTimeri, @function
_Z24EventSetMillisecondTimeri:
.LFB3788:
	.cfi_startproc
	endbr64
	movl	$1, %eax
	ret
	.cfi_endproc
.LFE3788:
	.size	_Z24EventSetMillisecondTimeri, .-_Z24EventSetMillisecondTimeri
	.globl	_Z14EventKillTimerv
	.type	_Z14EventKillTimerv, @function
_Z14EventKillTimerv:
.LFB3789:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc
.LFE3789:
	.size	_Z14EventKillTimerv, .-_Z14EventKillTimerv
	.globl	_Z5PrintNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.type	_Z5PrintNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, @function
_Z5PrintNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE:
.LFB3790:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc
.LFE3790:
	.size	_Z5PrintNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, .-_Z5PrintNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.globl	_Z11PrintFormatPKcz
	.type	_Z11PrintFormatPKcz, @function
_Z11PrintFormatPKcz:
.LFB3791:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc
.LFE3791:
	.size	_Z11PrintFormatPKcz, .-_Z11PrintFormatPKcz
	.globl	_Z11TimeCurrentv
	.type	_Z11TimeCurrentv, @function
_Z11TimeCurrentv:
.LFB3793:
	.cfi_startproc
	endbr64
	movl	$1000, %eax
	ret
	.cfi_endproc
.LFE3793:
	.size	_Z11TimeCurrentv, .-_Z11TimeCurrentv
	.globl	_Z7TimeGMTv
	.type	_Z7TimeGMTv, @function
_Z7TimeGMTv:
.LFB3794:
	.cfi_startproc
	endbr64
	movl	$1000, %eax
	ret
	.cfi_endproc
.LFE3794:
	.size	_Z7TimeGMTv, .-_Z7TimeGMTv
	.globl	_Z12TimeToStructlR11MqlDateTime
	.type	_Z12TimeToStructlR11MqlDateTime, @function
_Z12TimeToStructlR11MqlDateTime:
.LFB3795:
	.cfi_startproc
	endbr64
	movl	$2026, (%rsi)
	movl	$1, 4(%rsi)
	movl	$1, 8(%rsi)
	movl	$12, 12(%rsi)
	movl	$0, 16(%rsi)
	movl	$0, 20(%rsi)
	movl	$4, 24(%rsi)
	ret
	.cfi_endproc
.LFE3795:
	.size	_Z12TimeToStructlR11MqlDateTime, .-_Z12TimeToStructlR11MqlDateTime
	.globl	_Z12StringToTimeNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.type	_Z12StringToTimeNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, @function
_Z12StringToTimeNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE:
.LFB3796:
	.cfi_startproc
	endbr64
	movl	$1000, %eax
	ret
	.cfi_endproc
.LFE3796:
	.size	_Z12StringToTimeNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, .-_Z12StringToTimeNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.section	.rodata.str1.1
.LC13:
	.string	"stol"
	.text
	.globl	_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.type	_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, @function
_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE:
.LFB3797:
	.cfi_startproc
	.cfi_personality 0x9b,DW.ref.__gxx_personality_v0
	.cfi_lsda 0x1b,.LLSDA3797
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$16, %rsp
	.cfi_def_cfa_offset 48
	movq	%fs:40, %rax
	movq	%rax, 8(%rsp)
	xorl	%eax, %eax
	movq	(%rdi), %rbp
	call	__errno_location@PLT
	movq	%rax, %rbx
	movl	(%rax), %r12d
	movl	$0, (%rax)
	movq	%rsp, %rsi
	movl	$10, %edx
	movq	%rbp, %rdi
	call	__isoc23_strtol@PLT
	cmpq	(%rsp), %rbp
	je	.L183
	movl	(%rbx), %edx
	cmpl	$34, %edx
	je	.L184
	testl	%edx, %edx
	jne	.L171
	movl	%r12d, (%rbx)
.L171:
	movq	8(%rsp), %rdx
	subq	%fs:40, %rdx
	jne	.L185
	addq	$16, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L183:
	.cfi_restore_state
	movq	8(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L186
	leaq	.LC13(%rip), %rdi
.LEHB0:
	call	_ZSt24__throw_invalid_argumentPKc@PLT
.L181:
	endbr64
	movq	%rax, %rdi
	cmpl	$0, (%rbx)
	jne	.L178
	movl	%r12d, (%rbx)
.L178:
	movq	8(%rsp), %rax
	subq	%fs:40, %rax
	je	.L179
	call	__stack_chk_fail@PLT
.L186:
	call	__stack_chk_fail@PLT
.L184:
	movq	8(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L187
	leaq	.LC13(%rip), %rdi
	call	_ZSt20__throw_out_of_rangePKc@PLT
.LEHE0:
.L187:
	call	__stack_chk_fail@PLT
.L179:
.LEHB1:
	call	_Unwind_Resume@PLT
.LEHE1:
.L185:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3797:
	.globl	__gxx_personality_v0
	.section	.gcc_except_table,"a",@progbits
.LLSDA3797:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3797-.LLSDACSB3797
.LLSDACSB3797:
	.uleb128 .LEHB0-.LFB3797
	.uleb128 .LEHE0-.LEHB0
	.uleb128 .L181-.LFB3797
	.uleb128 0
	.uleb128 .LEHB1-.LFB3797
	.uleb128 .LEHE1-.LEHB1
	.uleb128 0
	.uleb128 0
.LLSDACSE3797:
	.text
	.size	_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, .-_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.globl	_Z6Periodv
	.type	_Z6Periodv, @function
_Z6Periodv:
.LFB3798:
	.cfi_startproc
	endbr64
	movl	$1, %eax
	ret
	.cfi_endproc
.LFE3798:
	.size	_Z6Periodv, .-_Z6Periodv
	.globl	_Z5iOpenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.type	_Z5iOpenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, @function
_Z5iOpenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii:
.LFB3799:
	.cfi_startproc
	endbr64
	movsd	.LC10(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3799:
	.size	_Z5iOpenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, .-_Z5iOpenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.globl	_Z6iCloseNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.type	_Z6iCloseNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, @function
_Z6iCloseNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii:
.LFB3800:
	.cfi_startproc
	endbr64
	movsd	.LC14(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3800:
	.size	_Z6iCloseNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, .-_Z6iCloseNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.globl	_Z5iHighNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.type	_Z5iHighNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, @function
_Z5iHighNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii:
.LFB3801:
	.cfi_startproc
	endbr64
	movsd	.LC15(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3801:
	.size	_Z5iHighNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, .-_Z5iHighNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.globl	_Z4iLowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.type	_Z4iLowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, @function
_Z4iLowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii:
.LFB3802:
	.cfi_startproc
	endbr64
	movsd	.LC16(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3802:
	.size	_Z4iLowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, .-_Z4iLowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.globl	_Z13StringToUpperRNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.type	_Z13StringToUpperRNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, @function
_Z13StringToUpperRNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE:
.LFB3803:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$8, %rsp
	.cfi_def_cfa_offset 32
	movq	(%rdi), %rbx
	movq	%rbx, %rbp
	addq	8(%rdi), %rbp
	cmpq	%rbx, %rbp
	je	.L193
.L195:
	movsbl	(%rbx), %edi
	call	toupper@PLT
	movb	%al, (%rbx)
	addq	$1, %rbx
	cmpq	%rbp, %rbx
	jne	.L195
.L193:
	addq	$8, %rsp
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3803:
	.size	_Z13StringToUpperRNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, .-_Z13StringToUpperRNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.globl	_Z9StringLenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.type	_Z9StringLenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, @function
_Z9StringLenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE:
.LFB3804:
	.cfi_startproc
	endbr64
	movl	8(%rdi), %eax
	ret
	.cfi_endproc
.LFE3804:
	.size	_Z9StringLenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, .-_Z9StringLenNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.section	.rodata.str1.1
.LC17:
	.string	"__pos <= size()"
	.section	.rodata.str1.8
	.align 8
.LC18:
	.ascii	"std::__cxx11::bas"
	.string	"ic_string<_CharT, _Traits, _Alloc>::reference std::__cxx11::basic_string<_CharT, _Traits, _Alloc>::operator[](size_type) [with _CharT = char; _Traits = std::char_traits<char>; _Alloc = std::allocator<char>; reference = char&; size_type = long unsigned int]"
	.align 8
.LC19:
	.string	"/usr/include/c++/13/bits/basic_string.h"
	.text
	.globl	_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	.type	_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi, @function
_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi:
.LFB3805:
	.cfi_startproc
	endbr64
	movslq	%esi, %rsi
	cmpq	%rsi, 8(%rdi)
	jb	.L204
	movq	(%rdi), %rax
	movsbl	(%rax,%rsi), %eax
	ret
.L204:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC17(%rip), %rcx
	leaq	.LC18(%rip), %rdx
	movl	$1258, %esi
	leaq	.LC19(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
	.cfi_endproc
.LFE3805:
	.size	_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi, .-_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	.globl	_Z17HistoryDealsTotalv
	.type	_Z17HistoryDealsTotalv, @function
_Z17HistoryDealsTotalv:
.LFB3819:
	.cfi_startproc
	endbr64
	movq	8+selectedHistoryDeals(%rip), %rax
	subq	selectedHistoryDeals(%rip), %rax
	sarq	$3, %rax
	ret
	.cfi_endproc
.LFE3819:
	.size	_Z17HistoryDealsTotalv, .-_Z17HistoryDealsTotalv
	.section	.rodata.str1.8
	.align 8
.LC20:
	.string	"vector::_M_range_check: __n (which is %zu) >= this->size() (which is %zu)"
	.text
	.globl	_Z20HistoryDealGetTicketi
	.type	_Z20HistoryDealGetTicketi, @function
_Z20HistoryDealGetTicketi:
.LFB3820:
	.cfi_startproc
	endbr64
	movslq	%edi, %rdi
	movq	selectedHistoryDeals(%rip), %rax
	movq	8+selectedHistoryDeals(%rip), %rdx
	subq	%rax, %rdx
	sarq	$3, %rdx
	cmpq	%rdx, %rdi
	jnb	.L211
	movq	(%rax,%rdi,8), %rax
	ret
.L211:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	%rdi, %rsi
	leaq	.LC20(%rip), %rdi
	movl	$0, %eax
	call	_ZSt24__throw_out_of_range_fmtPKcz@PLT
	.cfi_endproc
.LFE3820:
	.size	_Z20HistoryDealGetTicketi, .-_Z20HistoryDealGetTicketi
	.globl	_Z14ResetTradeItemR9TradeItem
	.type	_Z14ResetTradeItemR9TradeItem, @function
_Z14ResetTradeItemR9TradeItem:
.LFB3821:
	.cfi_startproc
	endbr64
	movl	$0, (%rdi)
	movl	$0, 4(%rdi)
	movl	$0, 8(%rdi)
	movl	$-1, 12(%rdi)
	movl	$-1, 16(%rdi)
	movq	$0x000000000, 24(%rdi)
	movq	$0x000000000, 32(%rdi)
	movq	$0x000000000, 40(%rdi)
	movq	$0, 48(%rdi)
	movq	$0, 56(%rdi)
	movq	$0, 64(%rdi)
	movq	$0x000000000, 72(%rdi)
	movq	$0x000000000, 80(%rdi)
	movq	$0x000000000, 88(%rdi)
	movq	$0x000000000, 96(%rdi)
	movb	$0, 104(%rdi)
	movb	$0, 105(%rdi)
	movl	$0, 108(%rdi)
	movl	$0, 112(%rdi)
	movl	$0, 116(%rdi)
	movq	$0x000000000, 120(%rdi)
	movq	$0x000000000, 128(%rdi)
	movq	$0x000000000, 136(%rdi)
	movq	$0x000000000, 144(%rdi)
	movl	$0, 152(%rdi)
	movl	$0, 156(%rdi)
	movq	$0, 160(%rdi)
	movq	$0, 168(%rdi)
	movq	$0, 176(%rdi)
	movq	$0, 184(%rdi)
	movl	$0, 192(%rdi)
	movl	$0, 196(%rdi)
	movb	$0, 200(%rdi)
	movq	$0x000000000, 208(%rdi)
	movq	$0x000000000, 216(%rdi)
	movq	$0x000000000, 224(%rdi)
	movq	$0x000000000, 232(%rdi)
	ret
	.cfi_endproc
.LFE3821:
	.size	_Z14ResetTradeItemR9TradeItem, .-_Z14ResetTradeItemR9TradeItem
	.globl	_Z13GridIsCleanupR9GridState
	.type	_Z13GridIsCleanupR9GridState, @function
_Z13GridIsCleanupR9GridState:
.LFB3823:
	.cfi_startproc
	endbr64
	cmpl	$4, (%rdi)
	sete	%al
	ret
	.cfi_endproc
.LFE3823:
	.size	_Z13GridIsCleanupR9GridState, .-_Z13GridIsCleanupR9GridState
	.globl	_Z12GridHasCycleR9GridState
	.type	_Z12GridHasCycleR9GridState, @function
_Z12GridHasCycleR9GridState:
.LFB3824:
	.cfi_startproc
	endbr64
	cmpl	$0, (%rdi)
	setne	%al
	ret
	.cfi_endproc
.LFE3824:
	.size	_Z12GridHasCycleR9GridState, .-_Z12GridHasCycleR9GridState
	.globl	_Z18Profiler30ResetAllv
	.type	_Z18Profiler30ResetAllv, @function
_Z18Profiler30ResetAllv:
.LFB3832:
	.cfi_startproc
	endbr64
	movl	$0, %eax
	leaq	g_prof30LastUs(%rip), %r8
	leaq	g_prof30MaxAllUs(%rip), %rdi
	leaq	g_prof30IntervalMaxUs(%rip), %rsi
	leaq	g_prof30IntervalTotalUs(%rip), %rcx
	leaq	g_prof30IntervalCalls(%rip), %rdx
.L216:
	movq	$0, (%r8,%rax)
	movq	$0, (%rdi,%rax)
	movq	$0, (%rsi,%rax)
	movq	$0, (%rcx,%rax)
	movq	$0, (%rdx,%rax)
	addq	$8, %rax
	cmpq	$88, %rax
	jne	.L216
	ret
	.cfi_endproc
.LFE3832:
	.size	_Z18Profiler30ResetAllv, .-_Z18Profiler30ResetAllv
	.globl	_Z16Profiler30Recordim
	.type	_Z16Profiler30Recordim, @function
_Z16Profiler30Recordim:
.LFB3833:
	.cfi_startproc
	endbr64
	cmpb	$0, InpEnableCpuProfiler(%rip)
	je	.L222
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	movl	%edi, %ebx
	movq	%rsi, %rbp
	cmpl	$10, %edi
	jbe	.L225
.L218:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L225:
	.cfi_restore_state
	call	_Z19GetMicrosecondCountv
	subq	%rbp, %rax
	movq	%rax, %rdx
	movslq	%ebx, %rax
	leaq	g_prof30LastUs(%rip), %rcx
	movq	%rdx, (%rcx,%rax,8)
	leaq	g_prof30IntervalTotalUs(%rip), %rcx
	addq	%rdx, (%rcx,%rax,8)
	leaq	g_prof30IntervalCalls(%rip), %rcx
	addq	$1, (%rcx,%rax,8)
	leaq	g_prof30IntervalMaxUs(%rip), %rcx
	cmpq	%rdx, (%rcx,%rax,8)
	jnb	.L220
	movq	%rdx, (%rcx,%rax,8)
.L220:
	movslq	%ebx, %rax
	leaq	g_prof30MaxAllUs(%rip), %rcx
	cmpq	%rdx, (%rcx,%rax,8)
	jnb	.L218
	movq	%rdx, (%rcx,%rax,8)
	jmp	.L218
.L222:
	.cfi_def_cfa_offset 8
	.cfi_restore 3
	.cfi_restore 6
	ret
	.cfi_endproc
.LFE3833:
	.size	_Z16Profiler30Recordim, .-_Z16Profiler30Recordim
	.globl	_Z13TradeBookSizeR9GridState
	.type	_Z13TradeBookSizeR9GridState, @function
_Z13TradeBookSizeR9GridState:
.LFB3835:
	.cfi_startproc
	endbr64
	movq	16(%rdi), %rax
	subq	8(%rdi), %rax
	sarq	$4, %rax
	imull	$-286331153, %eax, %eax
	ret
	.cfi_endproc
.LFE3835:
	.size	_Z13TradeBookSizeR9GridState, .-_Z13TradeBookSizeR9GridState
	.section	.rodata.str1.8
	.align 8
.LC21:
	.string	"std::vector<_Tp, _Alloc>::reference std::vector<_Tp, _Alloc>::operator[](size_type) [with _Tp = TradeItem; _Alloc = std::allocator<TradeItem>; reference = TradeItem&; size_type = long unsigned int]"
	.text
	.globl	_Z12FindItemByIdR9GridStatej
	.type	_Z12FindItemByIdR9GridStatej, @function
_Z12FindItemByIdR9GridStatej:
.LFB3836:
	.cfi_startproc
	endbr64
	testl	%esi, %esi
	je	.L232
	movq	8(%rdi), %rdx
	movq	16(%rdi), %rcx
	subq	%rdx, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L233
	leal	-1(%rcx), %r8d
	movl	$0, %eax
	jmp	.L231
.L234:
	movq	%rdi, %rax
.L231:
	cmpq	%rax, %rcx
	je	.L238
	cmpl	%esi, (%rdx)
	je	.L227
	leaq	1(%rax), %rdi
	addq	$240, %rdx
	cmpq	%rax, %r8
	jne	.L234
	movl	$-1, %eax
	ret
.L238:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L232:
	.cfi_def_cfa_offset 8
	movl	$-1, %eax
	ret
.L233:
	movl	$-1, %eax
.L227:
	ret
	.cfi_endproc
.LFE3836:
	.size	_Z12FindItemByIdR9GridStatej, .-_Z12FindItemByIdR9GridStatej
	.globl	_Z21FindItemByOrderTicketR9GridStatem
	.type	_Z21FindItemByOrderTicketR9GridStatem, @function
_Z21FindItemByOrderTicketR9GridStatem:
.LFB3837:
	.cfi_startproc
	endbr64
	testq	%rsi, %rsi
	je	.L244
	movq	8(%rdi), %rdx
	movq	16(%rdi), %rcx
	subq	%rdx, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L245
	addq	$4, %rdx
	leal	-1(%rcx), %r8d
	movl	$0, %eax
	jmp	.L243
.L251:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L242:
	.cfi_def_cfa_offset 8
	leaq	1(%rax), %rdi
	addq	$240, %rdx
	cmpq	%rax, %r8
	je	.L250
	movq	%rdi, %rax
.L243:
	cmpq	%rax, %rcx
	je	.L251
	cmpl	$1, (%rdx)
	jne	.L242
	cmpq	%rsi, 44(%rdx)
	jne	.L242
.L239:
	ret
.L250:
	movl	$-1, %eax
	ret
.L244:
	movl	$-1, %eax
	ret
.L245:
	movl	$-1, %eax
	ret
	.cfi_endproc
.LFE3837:
	.size	_Z21FindItemByOrderTicketR9GridStatem, .-_Z21FindItemByOrderTicketR9GridStatem
	.globl	_Z24FindItemByPositionTicketR9GridStatem
	.type	_Z24FindItemByPositionTicketR9GridStatem, @function
_Z24FindItemByPositionTicketR9GridStatem:
.LFB3838:
	.cfi_startproc
	endbr64
	testq	%rsi, %rsi
	je	.L257
	movq	8(%rdi), %rdx
	movq	16(%rdi), %rcx
	subq	%rdx, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L258
	addq	$56, %rdx
	leal	-1(%rcx), %r8d
	movl	$0, %eax
	jmp	.L256
.L259:
	movq	%rdi, %rax
.L256:
	cmpq	%rax, %rcx
	je	.L263
	cmpq	%rsi, (%rdx)
	je	.L252
	leaq	1(%rax), %rdi
	addq	$240, %rdx
	cmpq	%rax, %r8
	jne	.L259
	movl	$-1, %eax
	ret
.L263:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L257:
	.cfi_def_cfa_offset 8
	movl	$-1, %eax
	ret
.L258:
	movl	$-1, %eax
.L252:
	ret
	.cfi_endproc
.LFE3838:
	.size	_Z24FindItemByPositionTicketR9GridStatem, .-_Z24FindItemByPositionTicketR9GridStatem
	.globl	_Z19FindItemByRequestIdR9GridStatej
	.type	_Z19FindItemByRequestIdR9GridStatej, @function
_Z19FindItemByRequestIdR9GridStatej:
.LFB3839:
	.cfi_startproc
	endbr64
	testl	%esi, %esi
	je	.L269
	movq	8(%rdi), %rdx
	movq	16(%rdi), %rcx
	subq	%rdx, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L270
	addq	$152, %rdx
	leal	-1(%rcx), %r8d
	movl	$0, %eax
	jmp	.L268
.L271:
	movq	%rdi, %rax
.L268:
	cmpq	%rax, %rcx
	je	.L275
	cmpl	%esi, (%rdx)
	je	.L264
	leaq	1(%rax), %rdi
	addq	$240, %rdx
	cmpq	%rax, %r8
	jne	.L271
	movl	$-1, %eax
	ret
.L275:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L269:
	.cfi_def_cfa_offset 8
	movl	$-1, %eax
	ret
.L270:
	movl	$-1, %eax
.L264:
	ret
	.cfi_endproc
.LFE3839:
	.size	_Z19FindItemByRequestIdR9GridStatej, .-_Z19FindItemByRequestIdR9GridStatej
	.section	.text._Z7MathMaxIiiEDaT_T0_,"axG",@progbits,_Z7MathMaxIiiEDaT_T0_,comdat
	.weak	_Z7MathMaxIiiEDaT_T0_
	.type	_Z7MathMaxIiiEDaT_T0_, @function
_Z7MathMaxIiiEDaT_T0_:
.LFB3844:
	.cfi_startproc
	endbr64
	cmpl	%edi, %esi
	jg	.L279
	pxor	%xmm0, %xmm0
	cvtsi2sdl	%edi, %xmm0
	ret
.L279:
	pxor	%xmm0, %xmm0
	cvtsi2sdl	%esi, %xmm0
	ret
	.cfi_endproc
.LFE3844:
	.size	_Z7MathMaxIiiEDaT_T0_, .-_Z7MathMaxIiiEDaT_T0_
	.text
	.globl	_Z15CountBookOrdersR9GridState
	.type	_Z15CountBookOrdersR9GridState, @function
_Z15CountBookOrdersR9GridState:
.LFB3845:
	.cfi_startproc
	endbr64
	movq	8(%rdi), %rax
	movq	16(%rdi), %rcx
	subq	%rax, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdx
	imulq	%rdx, %rcx
	testl	%ecx, %ecx
	jle	.L286
	addq	$4, %rax
	leal	-1(%rcx), %edi
	movl	$0, %edx
	movl	$0, %r8d
	jmp	.L285
.L291:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L284:
	.cfi_def_cfa_offset 8
	addl	$1, %r8d
.L283:
	leaq	1(%rdx), %rsi
	addq	$240, %rax
	cmpq	%rdx, %rdi
	je	.L280
	movq	%rsi, %rdx
.L285:
	cmpq	%rdx, %rcx
	je	.L291
	cmpl	$1, (%rax)
	jne	.L283
	cmpb	$0, 100(%rax)
	jne	.L284
	cmpl	$1, 108(%rax)
	jne	.L283
	cmpl	$4, 112(%rax)
	jne	.L284
	jmp	.L283
.L286:
	movl	$0, %r8d
.L280:
	movl	%r8d, %eax
	ret
	.cfi_endproc
.LFE3845:
	.size	_Z15CountBookOrdersR9GridState, .-_Z15CountBookOrdersR9GridState
	.globl	_Z18CountBookPositionsR9GridState
	.type	_Z18CountBookPositionsR9GridState, @function
_Z18CountBookPositionsR9GridState:
.LFB3846:
	.cfi_startproc
	endbr64
	movq	8(%rdi), %rax
	movq	16(%rdi), %rcx
	subq	%rax, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdx
	imulq	%rdx, %rcx
	testl	%ecx, %ecx
	jle	.L297
	addq	$4, %rax
	leal	-1(%rcx), %r8d
	movl	$0, %edx
	movl	$0, %edi
	jmp	.L296
.L302:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L295:
	.cfi_def_cfa_offset 8
	leaq	1(%rdx), %rsi
	addq	$240, %rax
	cmpq	%rdx, %r8
	je	.L292
	movq	%rsi, %rdx
.L296:
	cmpq	%rdx, %rcx
	je	.L302
	cmpl	$2, (%rax)
	jne	.L295
	cmpb	$1, 100(%rax)
	sbbl	$-1, %edi
	jmp	.L295
.L297:
	movl	$0, %edi
.L292:
	movl	%edi, %eax
	ret
	.cfi_endproc
.LFE3846:
	.size	_Z18CountBookPositionsR9GridState, .-_Z18CountBookPositionsR9GridState
	.globl	_Z18CountBookOrderTypeR9GridState15ENUM_ORDER_TYPE
	.type	_Z18CountBookOrderTypeR9GridState15ENUM_ORDER_TYPE, @function
_Z18CountBookOrderTypeR9GridState15ENUM_ORDER_TYPE:
.LFB3847:
	.cfi_startproc
	endbr64
	movq	8(%rdi), %rax
	movq	16(%rdi), %rcx
	subq	%rax, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdx
	imulq	%rdx, %rcx
	testl	%ecx, %ecx
	jle	.L309
	addq	$4, %rax
	leal	-1(%rcx), %r8d
	movl	$0, %edx
	movl	$0, %r9d
	jmp	.L308
.L314:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L307:
	.cfi_def_cfa_offset 8
	cmpl	%esi, 8(%rdi)
	jne	.L306
	addl	$1, %r9d
.L306:
	leaq	1(%rdx), %rdi
	addq	$240, %rax
	cmpq	%rdx, %r8
	je	.L303
	movq	%rdi, %rdx
.L308:
	cmpq	%rdx, %rcx
	je	.L314
	movq	%rax, %rdi
	cmpl	$1, (%rax)
	jne	.L306
	cmpb	$0, 100(%rax)
	jne	.L307
	cmpl	$1, 108(%rax)
	jne	.L306
	cmpl	$4, 112(%rax)
	jne	.L307
	jmp	.L306
.L309:
	movl	$0, %r9d
.L303:
	movl	%r9d, %eax
	ret
	.cfi_endproc
.LFE3847:
	.size	_Z18CountBookOrderTypeR9GridState15ENUM_ORDER_TYPE, .-_Z18CountBookOrderTypeR9GridState15ENUM_ORDER_TYPE
	.globl	_Z19TerminalOrderExistsm
	.type	_Z19TerminalOrderExistsm, @function
_Z19TerminalOrderExistsm:
.LFB3850:
	.cfi_startproc
	endbr64
	movl	$0, %eax
	testq	%rdi, %rdi
	jne	.L322
	ret
.L322:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	call	_Z11OrderSelectm
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3850:
	.size	_Z19TerminalOrderExistsm, .-_Z19TerminalOrderExistsm
	.globl	_Z22TerminalPositionExistsm
	.type	_Z22TerminalPositionExistsm, @function
_Z22TerminalPositionExistsm:
.LFB3851:
	.cfi_startproc
	endbr64
	movl	$0, %eax
	testq	%rdi, %rdi
	jne	.L330
	ret
.L330:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	call	_Z22PositionSelectByTicketm
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3851:
	.size	_Z22TerminalPositionExistsm, .-_Z22TerminalPositionExistsm
	.globl	_Z22IsAsyncAcceptedRetcodei
	.type	_Z22IsAsyncAcceptedRetcodei, @function
_Z22IsAsyncAcceptedRetcodei:
.LFB3853:
	.cfi_startproc
	endbr64
	leal	-10008(%rdi), %eax
	cmpl	$2, %eax
	setbe	%al
	cmpl	$10025, %edi
	sete	%dl
	orl	%edx, %eax
	ret
	.cfi_endproc
.LFE3853:
	.size	_Z22IsAsyncAcceptedRetcodei, .-_Z22IsAsyncAcceptedRetcodei
	.globl	_Z18RequestDeleteOrderR9GridStatem
	.type	_Z18RequestDeleteOrderR9GridStatem, @function
_Z18RequestDeleteOrderR9GridStatem:
.LFB3856:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	call	_Z21FindItemByOrderTicketR9GridStatem
	testl	%eax, %eax
	js	.L343
	cltq
	movq	8(%rbx), %rcx
	movq	16(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$4, %rdx
	movabsq	$-1229782938247303441, %rsi
	imulq	%rsi, %rdx
	cmpq	%rdx, %rax
	jnb	.L346
	movq	%rax, %rdx
	salq	$4, %rdx
	subq	%rax, %rdx
	salq	$4, %rdx
	addq	%rdx, %rcx
	movzbl	105(%rcx), %esi
	testb	%sil, %sil
	jne	.L344
	movl	116(%rcx), %edi
	subl	$2, %edi
	cmpl	$1, %edi
	jbe	.L332
	movb	$0, 200(%rcx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L347
	movl	$2, 112(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L348
	movl	$1, 116(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L349
	movl	$0, 152(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L350
	movl	$0, 156(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L351
	movq	$0, 160(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L352
	movq	$0, 168(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L353
	movq	$0, 176(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L354
	movq	$0, 184(%rsi,%rdx)
	movl	$1, %esi
	jmp	.L332
.L346:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L347:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L348:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L349:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L350:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L351:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L352:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L353:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L354:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L343:
	movl	$0, %esi
.L332:
	movl	%esi, %eax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L344:
	.cfi_restore_state
	movl	$0, %esi
	jmp	.L332
	.cfi_endproc
.LFE3856:
	.size	_Z18RequestDeleteOrderR9GridStatem, .-_Z18RequestDeleteOrderR9GridStatem
	.globl	_Z20RequestClosePositionR9GridStatem
	.type	_Z20RequestClosePositionR9GridStatem, @function
_Z20RequestClosePositionR9GridStatem:
.LFB3857:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	call	_Z24FindItemByPositionTicketR9GridStatem
	testl	%eax, %eax
	js	.L365
	cltq
	movq	8(%rbx), %rcx
	movq	16(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$4, %rdx
	movabsq	$-1229782938247303441, %rsi
	imulq	%rsi, %rdx
	cmpq	%rdx, %rax
	jnb	.L368
	movq	%rax, %rdx
	salq	$4, %rdx
	subq	%rax, %rdx
	salq	$4, %rdx
	addq	%rdx, %rcx
	movzbl	105(%rcx), %esi
	testb	%sil, %sil
	jne	.L366
	movl	116(%rcx), %edi
	subl	$2, %edi
	cmpl	$1, %edi
	jbe	.L355
	movl	$3, 112(%rcx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L369
	movl	$1, 116(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L370
	movl	$0, 152(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L371
	movl	$0, 156(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L372
	movq	$0, 160(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L373
	movq	$0, 168(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L374
	movq	$0, 176(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L375
	movq	$0, 184(%rsi,%rdx)
	movl	$1, %esi
	jmp	.L355
.L368:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L369:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L370:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L371:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L372:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L373:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L374:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L375:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L365:
	movl	$0, %esi
.L355:
	movl	%esi, %eax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L366:
	.cfi_restore_state
	movl	$0, %esi
	jmp	.L355
	.cfi_endproc
.LFE3857:
	.size	_Z20RequestClosePositionR9GridStatem, .-_Z20RequestClosePositionR9GridStatem
	.globl	_Z15RequestModifySLR9GridStatemd
	.type	_Z15RequestModifySLR9GridStatemd, @function
_Z15RequestModifySLR9GridStatemd:
.LFB3858:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$24, %rsp
	.cfi_def_cfa_offset 48
	movsd	%xmm0, 8(%rsp)
	cmpl	$4, (%rdi)
	je	.L387
	movq	%rdi, %rbx
	movzbl	370(%rdi), %ebp
	testb	%bpl, %bpl
	je	.L391
	movl	$0, %ebp
.L376:
	movl	%ebp, %eax
	addq	$24, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L391:
	.cfi_restore_state
	call	_Z24FindItemByPositionTicketR9GridStatem
	testl	%eax, %eax
	js	.L376
	cltq
	movq	8(%rbx), %rcx
	movq	16(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$4, %rdx
	movabsq	$-1229782938247303441, %rsi
	imulq	%rsi, %rdx
	cmpq	%rdx, %rax
	jnb	.L392
	movq	%rax, %rdx
	salq	$4, %rdx
	subq	%rax, %rdx
	salq	$4, %rdx
	addq	%rdx, %rcx
	movzbl	105(%rcx), %edi
	testb	%dil, %dil
	jne	.L376
	movl	116(%rcx), %esi
	subl	$2, %esi
	cmpl	$1, %esi
	jbe	.L389
	movsd	8(%rsp), %xmm1
	movsd	%xmm1, 136(%rcx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L393
	movl	$4, 112(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L394
	movl	$1, 116(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L395
	movl	$0, 152(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L396
	movl	$0, 156(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L397
	movq	$0, 160(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L398
	movq	$0, 168(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L399
	movq	$0, 176(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L400
	movq	$0, 184(%rsi,%rdx)
	movl	$1, %ebp
	jmp	.L376
.L392:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L393:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L394:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L395:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L396:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L397:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L398:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L399:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L400:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L387:
	movl	$0, %ebp
	jmp	.L376
.L389:
	movl	%edi, %ebp
	jmp	.L376
	.cfi_endproc
.LFE3858:
	.size	_Z15RequestModifySLR9GridStatemd, .-_Z15RequestModifySLR9GridStatemd
	.globl	_Z19RequestReplaceOrderR9GridStatemdddd
	.type	_Z19RequestReplaceOrderR9GridStatemdddd, @function
_Z19RequestReplaceOrderR9GridStatemdddd:
.LFB3859:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$32, %rsp
	.cfi_def_cfa_offset 64
	movsd	%xmm0, (%rsp)
	movsd	%xmm1, 8(%rsp)
	movsd	%xmm2, 16(%rsp)
	movsd	%xmm3, 24(%rsp)
	cmpl	$4, (%rdi)
	je	.L408
	movq	%rdi, %rbx
	movq	%rsi, %rbp
	movl	$0, %r12d
	cmpb	$0, 370(%rdi)
	je	.L411
.L401:
	movl	%r12d, %eax
	addq	$32, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L411:
	.cfi_restore_state
	call	_Z18RequestDeleteOrderR9GridStatem
	movl	%eax, %r12d
	testb	%al, %al
	je	.L401
	movq	%rbp, %rsi
	movq	%rbx, %rdi
	call	_Z21FindItemByOrderTicketR9GridStatem
	cltq
	movq	8(%rbx), %rcx
	movq	16(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$4, %rdx
	movabsq	$-1229782938247303441, %rsi
	imulq	%rsi, %rdx
	cmpq	%rdx, %rax
	jnb	.L412
	movq	%rax, %rdx
	salq	$4, %rdx
	subq	%rax, %rdx
	salq	$4, %rdx
	movb	$1, 200(%rcx,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L413
	movsd	(%rsp), %xmm4
	movsd	%xmm4, 208(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L414
	movsd	8(%rsp), %xmm5
	movsd	%xmm5, 216(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L415
	movsd	16(%rsp), %xmm6
	movsd	%xmm6, 224(%rsi,%rdx)
	movq	8(%rbx), %rsi
	movq	16(%rbx), %rcx
	subq	%rsi, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdi
	imulq	%rdi, %rcx
	cmpq	%rcx, %rax
	jnb	.L416
	movsd	24(%rsp), %xmm7
	movsd	%xmm7, 232(%rsi,%rdx)
	jmp	.L401
.L412:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L413:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L414:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L415:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L416:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L408:
	movl	$0, %r12d
	jmp	.L401
	.cfi_endproc
.LFE3859:
	.size	_Z19RequestReplaceOrderR9GridStatemdddd, .-_Z19RequestReplaceOrderR9GridStatemdddd
	.globl	_Z17StrategyUTCMinutev
	.type	_Z17StrategyUTCMinutev, @function
_Z17StrategyUTCMinutev:
.LFB3863:
	.cfi_startproc
	endbr64
	subq	$56, %rsp
	.cfi_def_cfa_offset 64
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	movq	%rsp, %rsi
	movl	$1000, %edi
	call	_Z12TimeToStructlR11MqlDateTime
	imull	$60, 12(%rsp), %eax
	addl	16(%rsp), %eax
	movq	40(%rsp), %rdx
	subq	%fs:40, %rdx
	jne	.L420
	addq	$56, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L420:
	.cfi_restore_state
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3863:
	.size	_Z17StrategyUTCMinutev, .-_Z17StrategyUTCMinutev
	.globl	_Z18StrategyIsBuyOrder15ENUM_ORDER_TYPE
	.type	_Z18StrategyIsBuyOrder15ENUM_ORDER_TYPE, @function
_Z18StrategyIsBuyOrder15ENUM_ORDER_TYPE:
.LFB3873:
	.cfi_startproc
	endbr64
	cmpl	$6, %edi
	ja	.L423
	movl	$84, %eax
	btq	%rdi, %rax
	setc	%al
	ret
.L423:
	movl	$0, %eax
	ret
	.cfi_endproc
.LFE3873:
	.size	_Z18StrategyIsBuyOrder15ENUM_ORDER_TYPE, .-_Z18StrategyIsBuyOrder15ENUM_ORDER_TYPE
	.globl	_Z28StrategyFirstLevelSLDistanceddd
	.type	_Z28StrategyFirstLevelSLDistanceddd, @function
_Z28StrategyFirstLevelSLDistanceddd:
.LFB3876:
	.cfi_startproc
	endbr64
	movl	InpFirstLevelSLMode(%rip), %eax
	cmpl	$3, %eax
	je	.L425
	ja	.L426
	cmpl	$1, %eax
	je	.L427
	cmpl	$2, %eax
	jne	.L431
	movsd	InpGridSpacing(%rip), %xmm0
	mulsd	InpFirstSLRangeFraction(%rip), %xmm0
	ret
.L431:
	pxor	%xmm0, %xmm0
	ret
.L426:
	cmpl	$4, %eax
	jne	.L432
	mulsd	InpFirstSLRangeFraction(%rip), %xmm0
	ret
.L432:
	pxor	%xmm0, %xmm0
	ret
.L427:
	addsd	%xmm2, %xmm1
	movapd	%xmm1, %xmm0
	ret
.L425:
	movsd	InpInitialGap(%rip), %xmm0
	mulsd	InpFirstSLRangeFraction(%rip), %xmm0
	ret
	.cfi_endproc
.LFE3876:
	.size	_Z28StrategyFirstLevelSLDistanceddd, .-_Z28StrategyFirstLevelSLDistanceddd
	.globl	_Z18StrategyNearestBuyR9GridState
	.type	_Z18StrategyNearestBuyR9GridState, @function
_Z18StrategyNearestBuyR9GridState:
.LFB3879:
	.cfi_startproc
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$24, %rsp
	.cfi_def_cfa_offset 80
	movq	8(%rdi), %rbx
	movq	16(%rdi), %r12
	subq	%rbx, %r12
	sarq	$4, %r12
	movabsq	$-1229782938247303441, %rax
	imulq	%rax, %r12
	testl	%r12d, %r12d
	jle	.L442
	addq	$4, %rbx
	leal	-1(%r12), %r14d
	movl	$0, %ebp
	movq	$0x000000000, 8(%rsp)
	jmp	.L441
.L449:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L437:
	movsd	20(%rbx), %xmm0
	jmp	.L438
.L447:
	minsd	8(%rsp), %xmm0
	movsd	%xmm0, 8(%rsp)
.L436:
	leaq	1(%rbp), %rax
	addq	$240, %rbx
	cmpq	%rbp, %r14
	je	.L433
	movq	%rax, %rbp
.L441:
	cmpq	%rbp, %r12
	je	.L449
	cmpl	$1, (%rbx)
	jne	.L436
	movl	108(%rbx), %r15d
	movl	8(%rbx), %edi
	call	_Z18StrategyIsBuyOrder15ENUM_ORDER_TYPE
	cmpl	$2, %r15d
	je	.L436
	cmpb	$1, %al
	jne	.L436
	cmpb	$0, 100(%rbx)
	je	.L437
	movsd	68(%rbx), %xmm0
.L438:
	pxor	%xmm2, %xmm2
	comisd	%xmm2, %xmm0
	jbe	.L436
	pxor	%xmm1, %xmm1
	movsd	8(%rsp), %xmm3
	ucomisd	%xmm1, %xmm3
	jp	.L447
	jne	.L447
	movsd	%xmm0, 8(%rsp)
	jmp	.L436
.L442:
	movq	$0x000000000, 8(%rsp)
.L433:
	movsd	8(%rsp), %xmm0
	addq	$24, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3879:
	.size	_Z18StrategyNearestBuyR9GridState, .-_Z18StrategyNearestBuyR9GridState
	.globl	_Z19StrategyNearestSellR9GridState
	.type	_Z19StrategyNearestSellR9GridState, @function
_Z19StrategyNearestSellR9GridState:
.LFB3880:
	.cfi_startproc
	endbr64
	movq	8(%rdi), %rax
	movq	16(%rdi), %rcx
	subq	%rax, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdx
	imulq	%rdx, %rcx
	testl	%ecx, %ecx
	jle	.L459
	addq	$4, %rax
	leal	-1(%rcx), %r9d
	movl	$0, %edx
	pxor	%xmm0, %xmm0
	jmp	.L458
.L469:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L454:
	.cfi_def_cfa_offset 8
	movsd	20(%rax), %xmm1
	jmp	.L455
.L464:
	maxsd	%xmm0, %xmm1
	movapd	%xmm1, %xmm0
.L453:
	leaq	1(%rdx), %rsi
	addq	$240, %rax
	cmpq	%rdx, %r9
	je	.L468
	movq	%rsi, %rdx
.L458:
	cmpq	%rdx, %rcx
	je	.L469
	cmpl	$5, 8(%rax)
	setne	%sil
	cmpl	$1, (%rax)
	setne	%dil
	orb	%dil, %sil
	jne	.L453
	cmpl	$2, 108(%rax)
	je	.L453
	cmpb	$0, 100(%rax)
	je	.L454
	movsd	68(%rax), %xmm1
.L455:
	pxor	%xmm2, %xmm2
	comisd	%xmm2, %xmm1
	jbe	.L453
	ucomisd	%xmm2, %xmm0
	jp	.L464
	jne	.L464
	movapd	%xmm1, %xmm0
	jmp	.L453
.L468:
	ret
.L459:
	pxor	%xmm0, %xmm0
	ret
	.cfi_endproc
.LFE3880:
	.size	_Z19StrategyNearestSellR9GridState, .-_Z19StrategyNearestSellR9GridState
	.section	.rodata.str1.8
	.align 8
.LC22:
	.string	"std::vector<_Tp, _Alloc>::reference std::vector<_Tp, _Alloc>::operator[](size_type) [with _Tp = double; _Alloc = std::allocator<double>; reference = double&; size_type = long unsigned int]"
	.text
	.globl	_Z17StrategyFindLevelR9GridStated
	.type	_Z17StrategyFindLevelR9GridStated, @function
_Z17StrategyFindLevelR9GridStated:
.LFB3883:
	.cfi_startproc
	endbr64
	movq	152(%rdi), %rsi
	movq	160(%rdi), %rdx
	subq	%rsi, %rdx
	sarq	$3, %rdx
	testl	%edx, %edx
	jle	.L476
	movsd	InpGridSpacing(%rip), %xmm5
	leal	-1(%rdx), %edi
	movl	$0, %eax
	movsd	.LC23(%rip), %xmm4
	movq	.LC0(%rip), %xmm3
	jmp	.L475
.L477:
	movq	%rcx, %rax
.L475:
	cmpq	%rdx, %rax
	je	.L483
	movapd	%xmm5, %xmm2
	mulsd	%xmm4, %xmm2
	movsd	(%rsi,%rax,8), %xmm1
	subsd	%xmm0, %xmm1
	andpd	%xmm3, %xmm1
	comisd	%xmm1, %xmm2
	ja	.L470
	leaq	1(%rax), %rcx
	cmpq	%rdi, %rax
	jne	.L477
	movl	$-1, %eax
	ret
.L483:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC22(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L476:
	.cfi_def_cfa_offset 8
	movl	$-1, %eax
.L470:
	ret
	.cfi_endproc
.LFE3883:
	.size	_Z17StrategyFindLevelR9GridStated, .-_Z17StrategyFindLevelR9GridStated
	.section	.rodata.str1.8
	.align 8
.LC24:
	.string	"std::vector<_Tp, _Alloc>::reference std::vector<_Tp, _Alloc>::operator[](size_type) [with _Tp = int; _Alloc = std::allocator<int>; reference = int&; size_type = long unsigned int]"
	.text
	.globl	_Z19StrategyLevelVisitsR9GridStated
	.type	_Z19StrategyLevelVisitsR9GridStated, @function
_Z19StrategyLevelVisitsR9GridStated:
.LFB3884:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	call	_Z17StrategyFindLevelR9GridStated
	movl	$0, %edx
	testl	%eax, %eax
	jns	.L489
.L484:
	movl	%edx, %eax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L489:
	.cfi_restore_state
	cltq
	movq	176(%rbx), %rcx
	movq	184(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$2, %rdx
	cmpq	%rdx, %rax
	jnb	.L490
	movl	(%rcx,%rax,4), %edx
	jmp	.L484
.L490:
	leaq	.LC5(%rip), %rcx
	leaq	.LC24(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
	.cfi_endproc
.LFE3884:
	.size	_Z19StrategyLevelVisitsR9GridStated, .-_Z19StrategyLevelVisitsR9GridStated
	.globl	_Z20StrategyLevelBaseLotR9GridStated
	.type	_Z20StrategyLevelBaseLotR9GridStated, @function
_Z20StrategyLevelBaseLotR9GridStated:
.LFB3887:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	call	_Z17StrategyFindLevelR9GridStated
	pxor	%xmm0, %xmm0
	testl	%eax, %eax
	jns	.L496
.L491:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L496:
	.cfi_restore_state
	cltq
	movq	224(%rbx), %rcx
	movq	232(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$3, %rdx
	cmpq	%rdx, %rax
	jnb	.L497
	movsd	(%rcx,%rax,8), %xmm0
	jmp	.L491
.L497:
	leaq	.LC5(%rip), %rcx
	leaq	.LC22(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
	.cfi_endproc
.LFE3887:
	.size	_Z20StrategyLevelBaseLotR9GridStated, .-_Z20StrategyLevelBaseLotR9GridStated
	.globl	_Z23StrategyDirectionSwitch15ENUM_ORDER_TYPER9GridState
	.type	_Z23StrategyDirectionSwitch15ENUM_ORDER_TYPER9GridState, @function
_Z23StrategyDirectionSwitch15ENUM_ORDER_TYPER9GridState:
.LFB3905:
	.cfi_startproc
	endbr64
	movl	$0, %eax
	cmpq	$0, 120(%rsi)
	je	.L498
	cmpl	$0, 80(%rsi)
	sete	%dl
	testl	%edi, %edi
	sete	%al
	cmpb	%al, %dl
	setne	%al
.L498:
	ret
	.cfi_endproc
.LFE3905:
	.size	_Z23StrategyDirectionSwitch15ENUM_ORDER_TYPER9GridState, .-_Z23StrategyDirectionSwitch15ENUM_ORDER_TYPER9GridState
	.globl	_Z20StrategySLIsProgress18ENUM_POSITION_TYPEdd
	.type	_Z20StrategySLIsProgress18ENUM_POSITION_TYPEdd, @function
_Z20StrategySLIsProgress18ENUM_POSITION_TYPEdd:
.LFB3911:
	.cfi_startproc
	endbr64
	movl	$1, %eax
	pxor	%xmm2, %xmm2
	comisd	%xmm1, %xmm2
	jnb	.L501
	testl	%edi, %edi
	jne	.L503
	comisd	%xmm1, %xmm0
	seta	%al
	ret
.L503:
	comisd	%xmm0, %xmm1
	seta	%al
.L501:
	ret
	.cfi_endproc
.LFE3911:
	.size	_Z20StrategySLIsProgress18ENUM_POSITION_TYPEdd, .-_Z20StrategySLIsProgress18ENUM_POSITION_TYPEdd
	.globl	_Z23StrategyLiveWinnerCountR9GridState
	.type	_Z23StrategyLiveWinnerCountR9GridState, @function
_Z23StrategyLiveWinnerCountR9GridState:
.LFB3917:
	.cfi_startproc
	endbr64
	movq	8(%rdi), %rax
	movq	16(%rdi), %rcx
	subq	%rax, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdx
	imulq	%rdx, %rcx
	testl	%ecx, %ecx
	jle	.L510
	addq	$4, %rax
	leal	-1(%rcx), %r8d
	movl	$0, %edx
	movl	$0, %r9d
	jmp	.L509
.L515:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L508:
	.cfi_def_cfa_offset 8
	leaq	1(%rdx), %rsi
	addq	$240, %rax
	cmpq	%rdx, %r8
	je	.L505
	movq	%rsi, %rdx
.L509:
	cmpq	%rdx, %rcx
	je	.L515
	cmpl	$2, (%rax)
	jne	.L508
	cmpb	$0, 100(%rax)
	je	.L508
	movl	360(%rdi), %r10d
	cmpl	%r10d, 4(%rax)
	jne	.L508
	addl	$1, %r9d
	jmp	.L508
.L510:
	movl	$0, %r9d
.L505:
	movl	%r9d, %eax
	ret
	.cfi_endproc
.LFE3917:
	.size	_Z23StrategyLiveWinnerCountR9GridState, .-_Z23StrategyLiveWinnerCountR9GridState
	.globl	_Z19Strategy_BackgroundR9GridState
	.type	_Z19Strategy_BackgroundR9GridState, @function
_Z19Strategy_BackgroundR9GridState:
.LFB3923:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc
.LFE3923:
	.size	_Z19Strategy_BackgroundR9GridState, .-_Z19Strategy_BackgroundR9GridState
	.globl	_Z24AnyPlacementStillPendingR9GridState
	.type	_Z24AnyPlacementStillPendingR9GridState, @function
_Z24AnyPlacementStillPendingR9GridState:
.LFB3924:
	.cfi_startproc
	endbr64
	movq	8(%rdi), %rdx
	movq	16(%rdi), %rcx
	subq	%rdx, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L522
	addq	$112, %rdx
	leal	-1(%rcx), %edi
	movl	$0, %eax
	jmp	.L521
.L529:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L520:
	.cfi_def_cfa_offset 8
	leaq	1(%rax), %rsi
	addq	$240, %rdx
	cmpq	%rax, %rdi
	je	.L528
	movq	%rsi, %rax
.L521:
	cmpq	%rax, %rcx
	je	.L529
	cmpl	$1, (%rdx)
	jne	.L520
	cmpl	$4, 4(%rdx)
	je	.L520
	movl	$1, %eax
	ret
.L528:
	movl	$0, %eax
	ret
.L522:
	movl	$0, %eax
	ret
	.cfi_endproc
.LFE3924:
	.size	_Z24AnyPlacementStillPendingR9GridState, .-_Z24AnyPlacementStillPendingR9GridState
	.globl	_Z22HandleOrderTransactionR9GridStateR15TransactionItem
	.type	_Z22HandleOrderTransactionR9GridStateR15TransactionItem, @function
_Z22HandleOrderTransactionR9GridStateR15TransactionItem:
.LFB3940:
	.cfi_startproc
	endbr64
	cmpq	$0, 40(%rsi)
	jne	.L537
	movl	$1, %eax
	ret
.L537:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	movb	$1, 57(%rdi)
	movq	40(%rsi), %rsi
	call	_Z21FindItemByOrderTicketR9GridStatem
	testl	%eax, %eax
	jns	.L538
.L531:
	movl	$1, %eax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L538:
	.cfi_restore_state
	cltq
	movq	8(%rbx), %rcx
	movq	16(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$4, %rdx
	movabsq	$-1229782938247303441, %rsi
	imulq	%rsi, %rdx
	cmpq	%rdx, %rax
	jnb	.L539
	movq	%rax, %rdx
	salq	$4, %rdx
	subq	%rax, %rdx
	movq	%rdx, %rax
	salq	$4, %rax
	movb	$1, 105(%rcx,%rax)
	jmp	.L531
.L539:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
	.cfi_endproc
.LFE3940:
	.size	_Z22HandleOrderTransactionR9GridStateR15TransactionItem, .-_Z22HandleOrderTransactionR9GridStateR15TransactionItem
	.globl	_Z25HandlePositionTransactionR9GridStateR15TransactionItem
	.type	_Z25HandlePositionTransactionR9GridStateR15TransactionItem, @function
_Z25HandlePositionTransactionR9GridStateR15TransactionItem:
.LFB3941:
	.cfi_startproc
	endbr64
	cmpq	$0, 48(%rsi)
	jne	.L547
	movl	$1, %eax
	ret
.L547:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	movb	$1, 57(%rdi)
	movq	48(%rsi), %rsi
	call	_Z24FindItemByPositionTicketR9GridStatem
	testl	%eax, %eax
	jns	.L548
.L541:
	movl	$1, %eax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L548:
	.cfi_restore_state
	cltq
	movq	8(%rbx), %rcx
	movq	16(%rbx), %rdx
	subq	%rcx, %rdx
	sarq	$4, %rdx
	movabsq	$-1229782938247303441, %rsi
	imulq	%rsi, %rdx
	cmpq	%rdx, %rax
	jnb	.L549
	movq	%rax, %rdx
	salq	$4, %rdx
	subq	%rax, %rdx
	movq	%rdx, %rax
	salq	$4, %rax
	movb	$1, 105(%rcx,%rax)
	jmp	.L541
.L549:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
	.cfi_endproc
.LFE3941:
	.size	_Z25HandlePositionTransactionR9GridStateR15TransactionItem, .-_Z25HandlePositionTransactionR9GridStateR15TransactionItem
	.globl	_Z7TierDuemRmm
	.type	_Z7TierDuemRmm, @function
_Z7TierDuemRmm:
.LFB3955:
	.cfi_startproc
	endbr64
	movq	%rdi, %rcx
	subq	(%rsi), %rcx
	movl	$0, %eax
	cmpq	%rdx, %rcx
	jb	.L550
	movq	%rdi, (%rsi)
	movl	$1, %eax
.L550:
	ret
	.cfi_endproc
.LFE3955:
	.size	_Z7TierDuemRmm, .-_Z7TierDuemRmm
	.globl	_Z20FrameBudgetAvailablemm
	.type	_Z20FrameBudgetAvailablemm, @function
_Z20FrameBudgetAvailablemm:
.LFB3956:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	movq	%rdi, %rbp
	movq	%rsi, %rbx
	call	_Z19GetMicrosecondCountv
	subq	%rbp, %rax
	cmpq	%rbx, %rax
	setb	%al
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3956:
	.size	_Z20FrameBudgetAvailablemm, .-_Z20FrameBudgetAvailablemm
	.globl	_Z23TradeBookNeedsReconcileR9GridState
	.type	_Z23TradeBookNeedsReconcileR9GridState, @function
_Z23TradeBookNeedsReconcileR9GridState:
.LFB3957:
	.cfi_startproc
	endbr64
	movzbl	57(%rdi), %ecx
	testb	%cl, %cl
	jne	.L555
	cmpl	$4, (%rdi)
	je	.L559
	movq	8(%rdi), %rax
	movq	16(%rdi), %rsi
	subq	%rax, %rsi
	sarq	$4, %rsi
	movabsq	$-1229782938247303441, %rdx
	imulq	%rdx, %rsi
	testl	%esi, %esi
	jle	.L555
	addq	$105, %rax
	leal	-1(%rsi), %r8d
	movl	$0, %edx
	jmp	.L558
.L561:
	movq	%rdi, %rdx
.L558:
	cmpq	%rsi, %rdx
	je	.L565
	movzbl	(%rax), %ecx
	testb	%cl, %cl
	jne	.L555
	cmpl	$0, 11(%rax)
	jne	.L560
	leaq	1(%rdx), %rdi
	addq	$240, %rax
	cmpq	%r8, %rdx
	jne	.L561
	jmp	.L555
.L565:
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L559:
	.cfi_def_cfa_offset 8
	movl	$1, %ecx
.L555:
	movl	%ecx, %eax
	ret
.L560:
	movl	$1, %ecx
	jmp	.L555
	.cfi_endproc
.LFE3957:
	.size	_Z23TradeBookNeedsReconcileR9GridState, .-_Z23TradeBookNeedsReconcileR9GridState
	.globl	_Z8OnDeiniti
	.type	_Z8OnDeiniti, @function
_Z8OnDeiniti:
.LFB3986:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc
.LFE3986:
	.size	_Z8OnDeiniti, .-_Z8OnDeiniti
	.section	.text._ZNSt14_Function_baseD2Ev,"axG",@progbits,_ZNSt14_Function_baseD5Ev,comdat
	.align 2
	.weak	_ZNSt14_Function_baseD2Ev
	.type	_ZNSt14_Function_baseD2Ev, @function
_ZNSt14_Function_baseD2Ev:
.LFB4008:
	.cfi_startproc
	.cfi_personality 0x9b,DW.ref.__gxx_personality_v0
	.cfi_lsda 0x1b,.LLSDA4008
	endbr64
	movq	16(%rdi), %rax
	testq	%rax, %rax
	je	.L570
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movl	$3, %edx
	movq	%rdi, %rsi
	call	*%rax
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
.L570:
	ret
	.cfi_endproc
.LFE4008:
	.section	.gcc_except_table
.LLSDA4008:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE4008-.LLSDACSB4008
.LLSDACSB4008:
.LLSDACSE4008:
	.section	.text._ZNSt14_Function_baseD2Ev,"axG",@progbits,_ZNSt14_Function_baseD5Ev,comdat
	.size	_ZNSt14_Function_baseD2Ev, .-_ZNSt14_Function_baseD2Ev
	.weak	_ZNSt14_Function_baseD1Ev
	.set	_ZNSt14_Function_baseD1Ev,_ZNSt14_Function_baseD2Ev
	.section	.text._ZN9GridStateaSEOS_,"axG",@progbits,_ZN9GridStateaSEOS_,comdat
	.align 2
	.weak	_ZN9GridStateaSEOS_
	.type	_ZN9GridStateaSEOS_, @function
_ZN9GridStateaSEOS_:
.LFB4597:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$8, %rsp
	.cfi_def_cfa_offset 32
	movq	%rdi, %rbp
	movq	%rsi, %rbx
	movl	(%rsi), %eax
	movl	%eax, (%rdi)
	movq	8(%rdi), %rdi
	movq	24(%rbp), %rsi
	movq	8(%rbx), %rax
	movq	%rax, 8(%rbp)
	movq	16(%rbx), %rax
	movq	%rax, 16(%rbp)
	movq	24(%rbx), %rax
	movq	%rax, 24(%rbp)
	movq	$0, 8(%rbx)
	movq	$0, 16(%rbx)
	movq	$0, 24(%rbx)
	testq	%rdi, %rdi
	je	.L574
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L574:
	movl	32(%rbx), %eax
	movl	%eax, 32(%rbp)
	movq	40(%rbx), %rax
	movq	%rax, 40(%rbp)
	movl	48(%rbx), %eax
	movl	%eax, 48(%rbp)
	movl	52(%rbx), %eax
	movl	%eax, 52(%rbp)
	movzbl	56(%rbx), %eax
	movb	%al, 56(%rbp)
	movzbl	57(%rbx), %eax
	movb	%al, 57(%rbp)
	movl	60(%rbx), %eax
	movl	%eax, 60(%rbp)
	movsd	64(%rbx), %xmm0
	movsd	%xmm0, 64(%rbp)
	movsd	72(%rbx), %xmm0
	movsd	%xmm0, 72(%rbp)
	movl	80(%rbx), %eax
	movl	%eax, 80(%rbp)
	movl	84(%rbx), %eax
	movl	%eax, 84(%rbp)
	movsd	88(%rbx), %xmm0
	movsd	%xmm0, 88(%rbp)
	movsd	96(%rbx), %xmm0
	movsd	%xmm0, 96(%rbp)
	movsd	104(%rbx), %xmm0
	movsd	%xmm0, 104(%rbp)
	movq	112(%rbx), %rax
	movq	%rax, 112(%rbp)
	movq	120(%rbx), %rax
	movq	%rax, 120(%rbp)
	movsd	128(%rbx), %xmm0
	movsd	%xmm0, 128(%rbp)
	movsd	136(%rbx), %xmm0
	movsd	%xmm0, 136(%rbp)
	movsd	144(%rbx), %xmm0
	movsd	%xmm0, 144(%rbp)
	movq	152(%rbp), %rdi
	movq	168(%rbp), %rsi
	movq	152(%rbx), %rax
	movq	%rax, 152(%rbp)
	movq	160(%rbx), %rax
	movq	%rax, 160(%rbp)
	movq	168(%rbx), %rax
	movq	%rax, 168(%rbp)
	movq	$0, 152(%rbx)
	movq	$0, 160(%rbx)
	movq	$0, 168(%rbx)
	testq	%rdi, %rdi
	je	.L575
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L575:
	movq	176(%rbp), %rdi
	movq	192(%rbp), %rsi
	movq	176(%rbx), %rax
	movq	%rax, 176(%rbp)
	movq	184(%rbx), %rax
	movq	%rax, 184(%rbp)
	movq	192(%rbx), %rax
	movq	%rax, 192(%rbp)
	movq	$0, 176(%rbx)
	movq	$0, 184(%rbx)
	movq	$0, 192(%rbx)
	testq	%rdi, %rdi
	je	.L576
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L576:
	movq	200(%rbp), %rdi
	movq	216(%rbp), %rsi
	movq	200(%rbx), %rax
	movq	%rax, 200(%rbp)
	movq	208(%rbx), %rax
	movq	%rax, 208(%rbp)
	movq	216(%rbx), %rax
	movq	%rax, 216(%rbp)
	movq	$0, 200(%rbx)
	movq	$0, 208(%rbx)
	movq	$0, 216(%rbx)
	testq	%rdi, %rdi
	je	.L577
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L577:
	movq	224(%rbp), %rdi
	movq	240(%rbp), %rsi
	movq	224(%rbx), %rax
	movq	%rax, 224(%rbp)
	movq	232(%rbx), %rax
	movq	%rax, 232(%rbp)
	movq	240(%rbx), %rax
	movq	%rax, 240(%rbp)
	movq	$0, 224(%rbx)
	movq	$0, 232(%rbx)
	movq	$0, 240(%rbx)
	testq	%rdi, %rdi
	je	.L578
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L578:
	movq	248(%rbp), %rdi
	movq	264(%rbp), %rsi
	movq	248(%rbx), %rax
	movq	%rax, 248(%rbp)
	movq	256(%rbx), %rax
	movq	%rax, 256(%rbp)
	movq	264(%rbx), %rax
	movq	%rax, 264(%rbp)
	movq	$0, 248(%rbx)
	movq	$0, 256(%rbx)
	movq	$0, 264(%rbx)
	testq	%rdi, %rdi
	je	.L579
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L579:
	movl	272(%rbx), %eax
	movl	%eax, 272(%rbp)
	movsd	280(%rbx), %xmm0
	movsd	%xmm0, 280(%rbp)
	movsd	288(%rbx), %xmm0
	movsd	%xmm0, 288(%rbp)
	movsd	296(%rbx), %xmm0
	movsd	%xmm0, 296(%rbp)
	movsd	304(%rbx), %xmm0
	movsd	%xmm0, 304(%rbp)
	movsd	312(%rbx), %xmm0
	movsd	%xmm0, 312(%rbp)
	movsd	320(%rbx), %xmm0
	movsd	%xmm0, 320(%rbp)
	movsd	328(%rbx), %xmm0
	movsd	%xmm0, 328(%rbp)
	movsd	336(%rbx), %xmm0
	movsd	%xmm0, 336(%rbp)
	movzbl	344(%rbx), %eax
	movb	%al, 344(%rbp)
	movsd	352(%rbx), %xmm0
	movsd	%xmm0, 352(%rbp)
	movl	360(%rbx), %eax
	movl	%eax, 360(%rbp)
	movzbl	364(%rbx), %eax
	movb	%al, 364(%rbp)
	movzbl	365(%rbx), %eax
	movb	%al, 365(%rbp)
	movzbl	366(%rbx), %eax
	movb	%al, 366(%rbp)
	movzbl	367(%rbx), %eax
	movb	%al, 367(%rbp)
	movzbl	368(%rbx), %eax
	movb	%al, 368(%rbp)
	movzbl	369(%rbx), %eax
	movb	%al, 369(%rbp)
	movzbl	370(%rbx), %eax
	movb	%al, 370(%rbp)
	movzbl	371(%rbx), %eax
	movb	%al, 371(%rbp)
	movq	376(%rbp), %rax
	leaq	392(%rbp), %rdx
	cmpq	%rdx, %rax
	je	.L615
	movq	376(%rbx), %rdx
	leaq	392(%rbx), %rcx
	cmpq	%rdx, %rcx
	je	.L607
	movq	392(%rbp), %rsi
	movq	%rdx, 376(%rbp)
	movq	384(%rbx), %rdx
	movq	%rdx, 384(%rbp)
	movq	392(%rbx), %rdx
	movq	%rdx, 392(%rbp)
	testq	%rax, %rax
	je	.L591
	movq	%rax, 376(%rbx)
	movq	%rsi, 392(%rbx)
.L582:
	movq	$0, 384(%rbx)
	movq	376(%rbx), %rax
	movb	$0, (%rax)
	movq	408(%rbp), %rax
	leaq	424(%rbp), %rdx
	cmpq	%rdx, %rax
	je	.L616
	movq	408(%rbx), %rdx
	leaq	424(%rbx), %rcx
	cmpq	%rdx, %rcx
	je	.L617
	movq	424(%rbp), %rsi
	movq	%rdx, 408(%rbp)
	movq	416(%rbx), %rdx
	movq	%rdx, 416(%rbp)
	movq	424(%rbx), %rdx
	movq	%rdx, 424(%rbp)
	testq	%rax, %rax
	je	.L603
	movq	%rax, 408(%rbx)
	movq	%rsi, 424(%rbx)
.L594:
	movq	$0, 416(%rbx)
	movq	408(%rbx), %rax
	movb	$0, (%rax)
	movq	440(%rbx), %rax
	movq	%rax, 440(%rbp)
	movq	448(%rbx), %rax
	movq	%rax, 448(%rbp)
	movq	%rbp, %rax
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L615:
	.cfi_restore_state
	movq	376(%rbx), %rdx
	leaq	392(%rbx), %rcx
	cmpq	%rcx, %rdx
	je	.L618
	movq	%rdx, 376(%rbp)
	movq	384(%rbx), %rax
	movq	%rax, 384(%rbp)
	movq	392(%rbx), %rax
	movq	%rax, 392(%rbp)
.L591:
	movq	%rcx, 376(%rbx)
	jmp	.L582
.L618:
	movq	%rcx, %rdx
.L607:
	movq	384(%rbx), %rcx
	leaq	376(%rbx), %rdi
	leaq	376(%rbp), %rsi
	cmpq	%rsi, %rdi
	je	.L582
	testq	%rcx, %rcx
	jne	.L619
.L583:
	movq	384(%rbx), %rax
	movq	%rax, 384(%rbp)
	movq	376(%rbp), %rdx
	movb	$0, (%rdx,%rax)
	jmp	.L582
.L619:
	cmpq	$1, %rcx
	je	.L620
	movq	%rdx, %rdi
	cmpl	$8, %ecx
	jnb	.L585
	testb	$4, %cl
	jne	.L621
	testl	%ecx, %ecx
	je	.L583
	movzbl	(%rdx), %edx
	movb	%dl, (%rax)
	testb	$2, %cl
	je	.L583
	movl	%ecx, %ecx
	movzwl	-2(%rdi,%rcx), %edx
	movw	%dx, -2(%rax,%rcx)
	jmp	.L583
.L620:
	movzbl	(%rdx), %edx
	movb	%dl, (%rax)
	jmp	.L583
.L621:
	movl	(%rdx), %edx
	movl	%edx, (%rax)
	movl	%ecx, %ecx
	movl	-4(%rdi,%rcx), %edx
	movl	%edx, -4(%rax,%rcx)
	jmp	.L583
.L585:
	movq	(%rdx), %rsi
	movq	%rsi, (%rax)
	movl	%ecx, %esi
	movq	-8(%rdx,%rsi), %rdi
	movq	%rdi, -8(%rax,%rsi)
	leaq	8(%rax), %rsi
	andq	$-8, %rsi
	subq	%rsi, %rax
	subq	%rax, %rdx
	movq	%rdx, %rdi
	addl	%eax, %ecx
	andl	$-8, %ecx
	cmpl	$8, %ecx
	jb	.L583
	andl	$-8, %ecx
	movl	$0, %eax
.L589:
	movl	%eax, %edx
	movq	(%rdi,%rdx), %r8
	movq	%r8, (%rsi,%rdx)
	addl	$8, %eax
	cmpl	%ecx, %eax
	jb	.L589
	jmp	.L583
.L616:
	movq	408(%rbx), %rdx
	leaq	424(%rbx), %rcx
	cmpq	%rdx, %rcx
	je	.L622
	movq	%rdx, 408(%rbp)
	movq	416(%rbx), %rax
	movq	%rax, 416(%rbp)
	movq	424(%rbx), %rax
	movq	%rax, 424(%rbp)
.L603:
	movq	%rcx, 408(%rbx)
	jmp	.L594
.L622:
	movq	416(%rbx), %rcx
	jmp	.L604
.L625:
	cmpq	$1, %rcx
	je	.L623
	movq	%rdx, %r8
	cmpl	$8, %ecx
	jnb	.L597
	testb	$4, %cl
	jne	.L624
	testl	%ecx, %ecx
	je	.L595
	movzbl	(%rdx), %edx
	movb	%dl, (%rax)
	testb	$2, %cl
	je	.L595
	movl	%ecx, %esi
	movzwl	-2(%r8,%rsi), %edx
	movw	%dx, -2(%rax,%rsi)
	jmp	.L595
.L623:
	movzbl	(%rdx), %edx
	movb	%dl, (%rax)
	jmp	.L595
.L624:
	movl	(%rdx), %edx
	movl	%edx, (%rax)
	movl	%ecx, %esi
	movl	-4(%r8,%rsi), %edx
	movl	%edx, -4(%rax,%rsi)
	jmp	.L595
.L597:
	movq	(%rdx), %rsi
	movq	%rsi, (%rax)
	movl	%ecx, %esi
	movq	-8(%rdx,%rsi), %rdi
	movq	%rdi, -8(%rax,%rsi)
	leaq	8(%rax), %rdi
	andq	$-8, %rdi
	subq	%rdi, %rax
	movq	%rax, %rsi
	subq	%rax, %rdx
	movq	%rdx, %r8
	addl	%ecx, %esi
	andl	$-8, %esi
	cmpl	$8, %esi
	jb	.L595
	andl	$-8, %esi
	movl	$0, %eax
.L601:
	movl	%eax, %edx
	movq	(%r8,%rdx), %rcx
	movq	%rcx, (%rdi,%rdx)
	addl	$8, %eax
	cmpl	%esi, %eax
	jb	.L601
	jmp	.L595
.L617:
	movq	416(%rbx), %rcx
.L604:
	leaq	408(%rbx), %rdi
	leaq	408(%rbp), %rsi
	cmpq	%rsi, %rdi
	je	.L594
	testq	%rcx, %rcx
	jne	.L625
.L595:
	movq	416(%rbx), %rax
	movq	%rax, 416(%rbp)
	movq	408(%rbp), %rdx
	movb	$0, (%rdx,%rax)
	jmp	.L594
	.cfi_endproc
.LFE4597:
	.size	_ZN9GridStateaSEOS_, .-_ZN9GridStateaSEOS_
	.section	.rodata.str1.1
.LC25:
	.string	"PASS "
	.text
	.globl	_Z5checkPKcSt8functionIFvvEE
	.type	_Z5checkPKcSt8functionIFvvEE, @function
_Z5checkPKcSt8functionIFvvEE:
.LFB4598:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	cmpq	$0, 16(%rsi)
	je	.L634
	movq	%rdi, %rbx
	movq	%rsi, %rdi
	call	*24(%rsi)
	addl	$1, passed(%rip)
	movl	$5, %edx
	leaq	.LC25(%rip), %rsi
	leaq	_ZSt4cout(%rip), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l@PLT
	testq	%rbx, %rbx
	je	.L635
	movq	%rbx, %rdi
	call	strlen@PLT
	movq	%rax, %rdx
	movq	%rbx, %rsi
	leaq	_ZSt4cout(%rip), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l@PLT
.L629:
	movq	_ZSt4cout(%rip), %rax
	movq	-24(%rax), %rax
	leaq	_ZSt4cout(%rip), %rdx
	movq	240(%rdx,%rax), %rbx
	testq	%rbx, %rbx
	je	.L636
	cmpb	$0, 56(%rbx)
	je	.L631
	movzbl	67(%rbx), %esi
.L632:
	movsbl	%sil, %esi
	leaq	_ZSt4cout(%rip), %rdi
	call	_ZNSo3putEc@PLT
	movq	%rax, %rdi
	call	_ZNSo5flushEv@PLT
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L634:
	.cfi_restore_state
	call	_ZSt25__throw_bad_function_callv@PLT
.L635:
	leaq	_ZSt4cout(%rip), %rdi
	movq	_ZSt4cout(%rip), %rax
	addq	-24(%rax), %rdi
	movl	32(%rdi), %esi
	orl	$1, %esi
	call	_ZNSt9basic_iosIcSt11char_traitsIcEE5clearESt12_Ios_Iostate@PLT
	jmp	.L629
.L636:
	call	_ZSt16__throw_bad_castv@PLT
.L631:
	movq	%rbx, %rdi
	call	_ZNKSt5ctypeIcE13_M_widen_initEv@PLT
	movq	(%rbx), %rax
	movl	$10, %esi
	movq	%rbx, %rdi
	call	*48(%rax)
	movl	%eax, %esi
	jmp	.L632
	.cfi_endproc
.LFE4598:
	.size	_Z5checkPKcSt8functionIFvvEE, .-_Z5checkPKcSt8functionIFvvEE
	.section	.rodata.str1.8
	.align 8
.LC26:
	.string	"Rev22.2 initial grid creates one PLACE intent per side and level"
	.align 8
.LC27:
	.string	"partial initial grid cleans up and retries the whole grid"
	.align 8
.LC28:
	.string	"nearest-grid SL candidate still requires a non-negative net basket"
	.align 8
.LC29:
	.string	"full position exit triggers cleanup after reconciliation removes the position item"
	.align 8
.LC30:
	.string	" strategy scenario groups passed\n"
	.text
	.globl	main
	.type	main, @function
main:
.LFB4599:
	.cfi_startproc
	.cfi_personality 0x9b,DW.ref.__gxx_personality_v0
	.cfi_lsda 0x1b,.LLSDA4599
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	subq	$48, %rsp
	.cfi_def_cfa_offset 64
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	movq	$0, (%rsp)
	movq	$0, 8(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE_E9_M_invokeERKSt9_Any_data(%rip), %rax
	movq	%rax, 24(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation(%rip), %rax
	movq	%rax, 16(%rsp)
	movq	%rsp, %rsi
	leaq	.LC26(%rip), %rdi
.LEHB2:
	call	_Z5checkPKcSt8functionIFvvEE
.LEHE2:
	movq	%rsp, %rbx
	movq	%rbx, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movq	$0, (%rsp)
	movq	$0, 8(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE0_E9_M_invokeERKSt9_Any_data(%rip), %rax
	movq	%rax, 24(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE0_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation(%rip), %rax
	movq	%rax, 16(%rsp)
	movq	%rbx, %rsi
	leaq	.LC27(%rip), %rdi
.LEHB3:
	call	_Z5checkPKcSt8functionIFvvEE
.LEHE3:
	movq	%rbx, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movq	$0, (%rsp)
	movq	$0, 8(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE1_E9_M_invokeERKSt9_Any_data(%rip), %rax
	movq	%rax, 24(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE1_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation(%rip), %rax
	movq	%rax, 16(%rsp)
	movq	%rbx, %rsi
	leaq	.LC28(%rip), %rdi
.LEHB4:
	call	_Z5checkPKcSt8functionIFvvEE
.LEHE4:
	movq	%rbx, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movq	$0, (%rsp)
	movq	$0, 8(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE2_E9_M_invokeERKSt9_Any_data(%rip), %rax
	movq	%rax, 24(%rsp)
	leaq	_ZNSt17_Function_handlerIFvvEZ4mainEUlvE2_E10_M_managerERSt9_Any_dataRKS3_St18_Manager_operation(%rip), %rax
	movq	%rax, 16(%rsp)
	movq	%rbx, %rsi
	leaq	.LC29(%rip), %rdi
.LEHB5:
	call	_Z5checkPKcSt8functionIFvvEE
.LEHE5:
	movq	%rsp, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movl	passed(%rip), %esi
	leaq	_ZSt4cout(%rip), %rdi
.LEHB6:
	call	_ZNSolsEi@PLT
	movq	%rax, %rdi
	leaq	.LC30(%rip), %rsi
	call	_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc@PLT
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L653
	movl	$0, %eax
	addq	$48, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
.L647:
	.cfi_restore_state
	endbr64
	movq	%rax, %rbx
	movq	%rsp, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	je	.L639
	call	__stack_chk_fail@PLT
.L639:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.L648:
	endbr64
	movq	%rax, %rbx
	movq	%rsp, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	je	.L641
	call	__stack_chk_fail@PLT
.L641:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.L649:
	endbr64
	movq	%rax, %rbx
	movq	%rsp, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	je	.L643
	call	__stack_chk_fail@PLT
.L643:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.L650:
	endbr64
	movq	%rax, %rbx
	movq	%rsp, %rdi
	call	_ZNSt14_Function_baseD2Ev
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	je	.L645
	call	__stack_chk_fail@PLT
.L645:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.LEHE6:
.L653:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE4599:
	.section	.gcc_except_table
.LLSDA4599:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE4599-.LLSDACSB4599
.LLSDACSB4599:
	.uleb128 .LEHB2-.LFB4599
	.uleb128 .LEHE2-.LEHB2
	.uleb128 .L647-.LFB4599
	.uleb128 0
	.uleb128 .LEHB3-.LFB4599
	.uleb128 .LEHE3-.LEHB3
	.uleb128 .L648-.LFB4599
	.uleb128 0
	.uleb128 .LEHB4-.LFB4599
	.uleb128 .LEHE4-.LEHB4
	.uleb128 .L649-.LFB4599
	.uleb128 0
	.uleb128 .LEHB5-.LFB4599
	.uleb128 .LEHE5-.LEHB5
	.uleb128 .L650-.LFB4599
	.uleb128 0
	.uleb128 .LEHB6-.LFB4599
	.uleb128 .LEHE6-.LEHB6
	.uleb128 0
	.uleb128 0
.LLSDACSE4599:
	.text
	.size	main, .-main
	.section	.text._ZNSt6vectorIiSaIiEED2Ev,"axG",@progbits,_ZNSt6vectorIiSaIiEED5Ev,comdat
	.align 2
	.weak	_ZNSt6vectorIiSaIiEED2Ev
	.type	_ZNSt6vectorIiSaIiEED2Ev, @function
_ZNSt6vectorIiSaIiEED2Ev:
.LFB5047:
	.cfi_startproc
	endbr64
	movq	(%rdi), %rax
	testq	%rax, %rax
	je	.L657
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	16(%rdi), %rsi
	subq	%rax, %rsi
	movq	%rax, %rdi
	call	_ZdlPvm@PLT
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
.L657:
	ret
	.cfi_endproc
.LFE5047:
	.size	_ZNSt6vectorIiSaIiEED2Ev, .-_ZNSt6vectorIiSaIiEED2Ev
	.weak	_ZNSt6vectorIiSaIiEED1Ev
	.set	_ZNSt6vectorIiSaIiEED1Ev,_ZNSt6vectorIiSaIiEED2Ev
	.section	.text._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv,"axG",@progbits,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv,comdat
	.align 2
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	.type	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv, @function
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv:
.LFB5197:
	.cfi_startproc
	endbr64
	movq	(%rdi), %rax
	leaq	16(%rdi), %rdx
	cmpq	%rdx, %rax
	je	.L663
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	16(%rdi), %rsi
	addq	$1, %rsi
	movq	%rax, %rdi
	call	_ZdlPvm@PLT
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
.L663:
	ret
	.cfi_endproc
.LFE5197:
	.size	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv, .-_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	.section	.text._ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E,"axG",@progbits,_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E,comdat
	.align 2
	.weak	_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	.type	_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E, @function
_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E:
.LFB5313:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movq	%rdi, %r12
	movq	%rsi, %rbx
	testq	%rsi, %rsi
	jne	.L669
.L666:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L672:
	.cfi_restore_state
	movq	120(%rbp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L668:
	movl	$152, %esi
	movq	%rbp, %rdi
	call	_ZdlPvm@PLT
	testq	%rbx, %rbx
	je	.L666
.L669:
	movq	24(%rbx), %rsi
	movq	%r12, %rdi
	call	_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	movq	%rbx, %rbp
	movq	16(%rbx), %rbx
	movq	104(%rbp), %rdi
	leaq	120(%rbp), %rax
	cmpq	%rax, %rdi
	jne	.L672
	jmp	.L668
	.cfi_endproc
.LFE5313:
	.size	_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E, .-_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	.section	.text._ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED2Ev,"axG",@progbits,_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED5Ev,comdat
	.align 2
	.weak	_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED2Ev
	.type	_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED2Ev, @function
_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED2Ev:
.LFB6499:
	.cfi_startproc
	endbr64
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	16(%rdi), %rsi
	call	_ZNSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE6499:
	.size	_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED2Ev, .-_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED2Ev
	.weak	_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED1Ev
	.set	_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED1Ev,_ZNSt3mapIm5OrderSt4lessImESaISt4pairIKmS0_EEED2Ev
	.section	.text._ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E,"axG",@progbits,_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E,comdat
	.align 2
	.weak	_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	.type	_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E, @function
_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E:
.LFB5321:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movq	%rdi, %r12
	movq	%rsi, %rbx
	testq	%rsi, %rsi
	jne	.L678
.L675:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L681:
	.cfi_restore_state
	movq	112(%rbp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L677:
	movl	$136, %esi
	movq	%rbp, %rdi
	call	_ZdlPvm@PLT
	testq	%rbx, %rbx
	je	.L675
.L678:
	movq	24(%rbx), %rsi
	movq	%r12, %rdi
	call	_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	movq	%rbx, %rbp
	movq	16(%rbx), %rbx
	movq	96(%rbp), %rdi
	leaq	112(%rbp), %rax
	cmpq	%rax, %rdi
	jne	.L681
	jmp	.L677
	.cfi_endproc
.LFE5321:
	.size	_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E, .-_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	.section	.text._ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED2Ev,"axG",@progbits,_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED5Ev,comdat
	.align 2
	.weak	_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED2Ev
	.type	_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED2Ev, @function
_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED2Ev:
.LFB6502:
	.cfi_startproc
	endbr64
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	16(%rdi), %rsi
	call	_ZNSt8_Rb_treeImSt4pairIKm4DealESt10_Select1stIS3_ESt4lessImESaIS3_EE8_M_eraseEPSt13_Rb_tree_nodeIS3_E
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE6502:
	.size	_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED2Ev, .-_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED2Ev
	.weak	_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED1Ev
	.set	_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED1Ev,_ZNSt3mapIm4DealSt4lessImESaISt4pairIKmS0_EEED2Ev
	.section	.text._ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_,"axG",@progbits,_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_,comdat
	.align 2
	.weak	_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_
	.type	_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_, @function
_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_:
.LFB5352:
	.cfi_startproc
	endbr64
	leaq	8(%rdi), %r8
	movq	16(%rdi), %rax
	testq	%rax, %rax
	je	.L689
	movq	(%rsi), %rdx
	movq	%r8, %rcx
	jmp	.L688
.L686:
	movq	24(%rax), %rax
.L687:
	testq	%rax, %rax
	je	.L691
.L688:
	cmpq	%rdx, 32(%rax)
	jb	.L686
	movq	%rax, %rcx
	movq	16(%rax), %rax
	jmp	.L687
.L691:
	cmpq	%rcx, %r8
	je	.L685
	cmpq	32(%rcx), %rdx
	cmovb	%r8, %rcx
.L685:
	movq	%rcx, %rax
	ret
.L689:
	movq	%r8, %rcx
	jmp	.L685
	.cfi_endproc
.LFE5352:
	.size	_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_, .-_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_
	.text
	.globl	_Z18HistoryOrderSelectm
	.type	_Z18HistoryOrderSelectm, @function
_Z18HistoryOrderSelectm:
.LFB3761:
	.cfi_startproc
	endbr64
	subq	$24, %rsp
	.cfi_def_cfa_offset 32
	movq	%rdi, 8(%rsp)
	leaq	8(%rsp), %rsi
	leaq	historyOrders(%rip), %rdi
	call	_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_
	leaq	8+historyOrders(%rip), %rdx
	cmpq	%rax, %rdx
	setne	%al
	addq	$24, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3761:
	.size	_Z18HistoryOrderSelectm, .-_Z18HistoryOrderSelectm
	.section	.rodata._ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_.str1.1,"aMS",@progbits,1
.LC31:
	.string	"vector::_M_realloc_insert"
	.section	.text._ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_,"axG",@progbits,_ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_,comdat
	.align 2
	.weak	_ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_
	.type	_ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_, @function
_ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_:
.LFB5399:
	.cfi_startproc
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$24, %rsp
	.cfi_def_cfa_offset 80
	movq	%rsi, (%rsp)
	movq	%rdx, 8(%rsp)
	movq	8(%rdi), %rbp
	movq	(%rdi), %r13
	movq	%rbp, %rax
	subq	%r13, %rax
	sarq	$3, %rax
	movabsq	$1152921504606846975, %rdx
	cmpq	%rdx, %rax
	je	.L711
	movq	%rdi, %rbx
	cmpq	%r13, %rbp
	movl	$1, %edx
	cmovne	%rax, %rdx
	addq	%rdx, %rax
	jc	.L697
	movabsq	$1152921504606846975, %r14
	cmpq	%r14, %rax
	cmovbe	%rax, %r14
	movq	(%rsp), %r15
	subq	%r13, %r15
	movl	$0, %r12d
	testq	%rax, %rax
	je	.L698
	jmp	.L705
.L711:
	leaq	.LC31(%rip), %rdi
	call	_ZSt20__throw_length_errorPKc@PLT
.L712:
	movq	%r15, %rdx
	movq	%r13, %rsi
	movq	%r12, %rdi
	call	memmove@PLT
	leaq	8(%r12,%r15), %r15
	movq	(%rsp), %rax
	subq	%rax, %rbp
	testq	%rbp, %rbp
	jg	.L700
	addq	%rbp, %r15
	movq	16(%rbx), %rsi
	subq	%r13, %rsi
	jmp	.L704
.L697:
	movq	(%rsp), %r15
	subq	%r13, %r15
	movabsq	$1152921504606846975, %r14
.L705:
	leaq	0(,%r14,8), %rdi
	call	_Znwm@PLT
	movq	%rax, %r12
.L698:
	movq	8(%rsp), %rax
	movq	(%rax), %rax
	movq	%rax, (%r12,%r15)
	testq	%r15, %r15
	jg	.L712
	leaq	8(%r12,%r15), %r15
	movq	(%rsp), %rax
	subq	%rax, %rbp
	testq	%rbp, %rbp
	jle	.L702
.L700:
	movq	%rbp, %rdx
	movq	(%rsp), %rsi
	movq	%r15, %rdi
	call	memcpy@PLT
.L702:
	addq	%rbp, %r15
	testq	%r13, %r13
	je	.L703
	movq	16(%rbx), %rsi
	subq	%r13, %rsi
.L704:
	movq	%r13, %rdi
	call	_ZdlPvm@PLT
.L703:
	movq	%r12, (%rbx)
	movq	%r15, 8(%rbx)
	leaq	(%r12,%r14,8), %rax
	movq	%rax, 16(%rbx)
	addq	$24, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE5399:
	.size	_ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_, .-_ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_
	.text
	.globl	_Z23HistorySelectByPositionm
	.type	_Z23HistorySelectByPositionm, @function
_Z23HistorySelectByPositionm:
.LFB3817:
	.cfi_startproc
	endbr64
	pushq	%r13
	.cfi_def_cfa_offset 16
	.cfi_offset 13, -16
	pushq	%r12
	.cfi_def_cfa_offset 24
	.cfi_offset 12, -24
	pushq	%rbp
	.cfi_def_cfa_offset 32
	.cfi_offset 6, -32
	pushq	%rbx
	.cfi_def_cfa_offset 40
	.cfi_offset 3, -40
	subq	$8, %rsp
	.cfi_def_cfa_offset 48
	movq	%rdi, %rbp
	movq	selectedHistoryDeals(%rip), %rax
	cmpq	8+selectedHistoryDeals(%rip), %rax
	je	.L714
	movq	%rax, 8+selectedHistoryDeals(%rip)
.L714:
	movq	24+historyDeals(%rip), %rbx
	leaq	8+historyDeals(%rip), %rax
	cmpq	%rax, %rbx
	je	.L715
	leaq	selectedHistoryDeals(%rip), %r13
	movq	%rax, %r12
	jmp	.L718
.L721:
	movq	32(%rbx), %rax
	movq	%rax, (%rsi)
	addq	$8, 8(%r13)
.L716:
	movq	%rbx, %rdi
	call	_ZSt18_Rb_tree_incrementPSt18_Rb_tree_node_base@PLT
	movq	%rax, %rbx
	cmpq	%r12, %rax
	je	.L715
.L718:
	cmpq	%rbp, 56(%rbx)
	jne	.L716
	movq	8(%r13), %rsi
	cmpq	16(%r13), %rsi
	jne	.L721
	leaq	32(%rbx), %rdx
	leaq	selectedHistoryDeals(%rip), %rdi
	call	_ZNSt6vectorImSaImEE17_M_realloc_insertIJRKmEEEvN9__gnu_cxx17__normal_iteratorIPmS1_EEDpOT_
	jmp	.L716
.L715:
	movl	$1, %eax
	addq	$8, %rsp
	.cfi_def_cfa_offset 40
	popq	%rbx
	.cfi_def_cfa_offset 32
	popq	%rbp
	.cfi_def_cfa_offset 24
	popq	%r12
	.cfi_def_cfa_offset 16
	popq	%r13
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3817:
	.size	_Z23HistorySelectByPositionm, .-_Z23HistorySelectByPositionm
	.section	.text._ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EESA_,"axG",@progbits,_ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EESA_,comdat
	.weak	_ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EESA_
	.type	_ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EESA_, @function
_ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EESA_:
.LFB5437:
	.cfi_startproc
	endbr64
	movq	8(%rdi), %rdx
	movl	$0, %eax
	cmpq	8(%rsi), %rdx
	je	.L730
.L727:
	ret
.L730:
	movl	$1, %eax
	testq	%rdx, %rdx
	je	.L727
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	(%rsi), %rsi
	movq	(%rdi), %rdi
	call	memcmp@PLT
	testl	%eax, %eax
	sete	%al
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE5437:
	.size	_ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EESA_, .-_ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EESA_
	.section	.rodata._ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm.str1.1,"aMS",@progbits,1
.LC32:
	.string	"vector::reserve"
	.section	.text._ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm,"axG",@progbits,_ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm,comdat
	.align 2
	.weak	_ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm
	.type	_ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm, @function
_ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm:
.LFB5469:
	.cfi_startproc
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$24, %rsp
	.cfi_def_cfa_offset 80
	movabsq	$76861433640456465, %rax
	cmpq	%rsi, %rax
	jb	.L749
	movq	%rdi, %r12
	movq	(%rdi), %rdx
	movq	16(%rdi), %rax
	subq	%rdx, %rax
	sarq	$3, %rax
	movabsq	$-1229782938247303441, %rcx
	imulq	%rcx, %rax
	cmpq	%rsi, %rax
	jnb	.L731
	movq	8(%rdi), %rax
	subq	%rdx, %rax
	movq	%rax, 8(%rsp)
	movq	%rsi, %r15
	salq	$4, %r15
	subq	%rsi, %r15
	salq	$3, %r15
	movq	%r15, %rdi
	call	_Znwm@PLT
	movq	%rax, %r14
	movq	8(%r12), %r13
	movq	(%r12), %rbp
	cmpq	%rbp, %r13
	je	.L734
	addq	$24, %rbp
	movq	%rax, %rbx
	jmp	.L744
.L749:
	leaq	.LC32(%rip), %rdi
	call	_ZSt20__throw_length_errorPKc@PLT
.L751:
	movq	-8(%rdx), %rdx
	addq	$1, %rdx
	cmpl	$8, %edx
	jnb	.L736
	testb	$4, %dl
	jne	.L750
	testl	%edx, %edx
	je	.L742
	movzbl	0(%rbp), %esi
	movb	%sil, (%rcx)
	testb	$2, %dl
	je	.L742
	movl	%edx, %edx
	movzwl	-2(%rbp,%rdx), %esi
	movw	%si, -2(%rcx,%rdx)
	jmp	.L742
.L750:
	movl	0(%rbp), %esi
	movl	%esi, (%rcx)
	movl	%edx, %edx
	movl	-4(%rbp,%rdx), %esi
	movl	%esi, -4(%rcx,%rdx)
	jmp	.L742
.L736:
	movq	0(%rbp), %rsi
	movq	%rsi, (%rcx)
	movl	%edx, %esi
	movq	-8(%rbp,%rsi), %rdi
	movq	%rdi, -8(%rcx,%rsi)
	leaq	8(%rcx), %rsi
	andq	$-8, %rsi
	subq	%rsi, %rcx
	movq	%rbp, %rdi
	subq	%rcx, %rdi
	addl	%ecx, %edx
	andl	$-8, %edx
	cmpl	$8, %edx
	jb	.L742
	andl	$-8, %edx
	movl	$0, %ecx
.L740:
	movl	%ecx, %r8d
	movq	(%rdi,%r8), %r9
	movq	%r9, (%rsi,%r8)
	addl	$8, %ecx
	cmpl	%edx, %ecx
	jb	.L740
	jmp	.L742
.L743:
	addq	$120, %rbx
	leaq	120(%rbp), %rax
	addq	$96, %rbp
	cmpq	%rbp, %r13
	je	.L734
	movq	%rax, %rbp
.L744:
	movq	%rbp, %rax
	movl	-24(%rbp), %edx
	movl	%edx, (%rbx)
	leaq	24(%rbx), %rcx
	movq	%rcx, 8(%rbx)
	movq	-16(%rbp), %rdx
	cmpq	%rdx, %rbp
	je	.L751
	movq	%rdx, 8(%rbx)
	movq	0(%rbp), %rdx
	movq	%rdx, 24(%rbx)
.L742:
	movq	-8(%rax), %rdx
	movq	%rdx, 16(%rbx)
	movq	%rax, -16(%rax)
	movq	$0, -8(%rax)
	movb	$0, (%rax)
	movq	16(%rax), %rdx
	movq	%rdx, 40(%rbx)
	movq	24(%rax), %rdx
	movq	%rdx, 48(%rbx)
	movq	32(%rax), %rdx
	movq	%rdx, 56(%rbx)
	movl	40(%rax), %edx
	movl	%edx, 64(%rbx)
	movsd	48(%rax), %xmm0
	movsd	%xmm0, 72(%rbx)
	movsd	56(%rax), %xmm0
	movsd	%xmm0, 80(%rbx)
	movl	64(%rax), %edx
	movl	%edx, 88(%rbx)
	movl	68(%rax), %edx
	movl	%edx, 92(%rbx)
	movq	72(%rax), %rdx
	movq	%rdx, 96(%rbx)
	movq	80(%rax), %rdx
	movq	%rdx, 104(%rbx)
	movl	88(%rax), %edx
	movl	%edx, 112(%rbx)
	movq	-16(%rax), %rdi
	cmpq	%rdi, %rax
	je	.L743
	movq	(%rax), %rsi
	addq	$1, %rsi
	call	_ZdlPvm@PLT
	jmp	.L743
.L734:
	movq	(%r12), %rdi
	testq	%rdi, %rdi
	je	.L745
	movq	16(%r12), %rsi
	subq	%rdi, %rsi
	call	_ZdlPvm@PLT
.L745:
	movq	%r14, (%r12)
	movq	8(%rsp), %rax
	addq	%r14, %rax
	movq	%rax, 8(%r12)
	addq	%r15, %r14
	movq	%r14, 16(%r12)
.L731:
	addq	$24, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE5469:
	.size	_ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm, .-_ZNSt6vectorI15TransactionItemSaIS0_EE7reserveEm
	.section	.rodata._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm.str1.1,"aMS",@progbits,1
.LC33:
	.string	"basic_string::_M_create"
	.section	.text._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm,"axG",@progbits,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm,comdat
	.align 2
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm
	.type	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm, @function
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm:
.LFB5610:
	.cfi_startproc
	endbr64
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movq	(%rsi), %rax
	movq	%rax, %rcx
	shrq	$62, %rcx
	jne	.L758
	cmpq	%rax, %rdx
	jnb	.L754
	addq	%rdx, %rdx
	cmpq	%rdx, %rax
	jnb	.L754
	movq	%rdx, %rax
	shrq	$62, %rax
	jne	.L755
	movq	%rdx, (%rsi)
.L754:
	movq	(%rsi), %rdi
	addq	$1, %rdi
	js	.L759
.L756:
	call	_Znwm@PLT
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L758:
	.cfi_restore_state
	leaq	.LC33(%rip), %rdi
	call	_ZSt20__throw_length_errorPKc@PLT
.L755:
	movabsq	$4611686018427387903, %rax
	movq	%rax, (%rsi)
	movabsq	$4611686018427387904, %rdi
	jmp	.L756
.L759:
	call	_ZSt17__throw_bad_allocv@PLT
	.cfi_endproc
.LFE5610:
	.size	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm, .-_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm
	.section	.text._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag,"axG",@progbits,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag,comdat
	.align 2
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	.type	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag, @function
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag:
.LFB5345:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$16, %rsp
	.cfi_def_cfa_offset 48
	movq	%rdi, %rbx
	movq	%rsi, %r12
	movq	%fs:40, %rax
	movq	%rax, 8(%rsp)
	xorl	%eax, %eax
	subq	%rsi, %rdx
	movq	%rdx, %rbp
	movq	%rdx, (%rsp)
	cmpq	$15, %rdx
	ja	.L767
	movq	(%rdi), %rdi
	cmpq	$1, %rdx
	jne	.L763
	movzbl	(%rsi), %eax
	movb	%al, (%rdi)
.L764:
	movq	(%rsp), %rax
	movq	%rax, 8(%rbx)
	movq	(%rbx), %rdx
	movb	$0, (%rdx,%rax)
	movq	8(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L768
	addq	$16, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L767:
	.cfi_restore_state
	movq	%rsp, %rsi
	movl	$0, %edx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm
	movq	%rax, %rdi
	movq	%rax, (%rbx)
	movq	(%rsp), %rax
	movq	%rax, 16(%rbx)
.L762:
	movq	%rbp, %rdx
	movq	%r12, %rsi
	call	memcpy@PLT
	jmp	.L764
.L763:
	testq	%rdx, %rdx
	je	.L764
	jmp	.L762
.L768:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE5345:
	.size	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag, .-_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	.text
	.globl	_Z18StrategyAlignPriced
	.type	_Z18StrategyAlignPriced, @function
_Z18StrategyAlignPriced:
.LFB3868:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	subq	$64, %rsp
	.cfi_def_cfa_offset 80
	movsd	%xmm0, 8(%rsp)
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbx
	movq	%rbx, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L770
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L770:
	movsd	8(%rsp), %xmm0
	divsd	.LC9(%rip), %xmm0
	call	round@PLT
	mulsd	.LC9(%rip), %xmm0
	movq	56(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L773
	addq	$64, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
.L773:
	.cfi_restore_state
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3868:
	.size	_Z18StrategyAlignPriced, .-_Z18StrategyAlignPriced
	.globl	_Z14InitAsyncTradev
	.type	_Z14InitAsyncTradev, @function
_Z14InitAsyncTradev:
.LFB3854:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	subq	$48, %rsp
	.cfi_def_cfa_offset 64
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	movq	%rsp, %rdi
	leaq	16(%rsp), %rbx
	movq	%rbx, (%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L775
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L775:
	movl	$2, g_asyncFillMode(%rip)
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L778
	addq	$48, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
.L778:
	.cfi_restore_state
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3854:
	.size	_Z14InitAsyncTradev, .-_Z14InitAsyncTradev
	.section	.rodata.str1.8
	.align 8
.LC34:
	.string	"std::string OrderGetString(int)"
	.section	.rodata.str1.1
.LC35:
	.string	"Validation/mt5_mock.hpp"
.LC36:
	.string	"selectedOrder>=0"
	.text
	.globl	_Z14OrderGetStringB5cxx11i
	.type	_Z14OrderGetStringB5cxx11i, @function
_Z14OrderGetStringB5cxx11i:
.LFB3752:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movl	selectedOrder(%rip), %edx
	testl	%edx, %edx
	js	.L783
	movq	%rdi, %rbx
	movslq	%edx, %rdx
	movq	orders(%rip), %rcx
	movq	8+orders(%rip), %rax
	subq	%rcx, %rax
	sarq	$4, %rax
	movabsq	$7905747460161236407, %rsi
	imulq	%rsi, %rax
	cmpq	%rax, %rdx
	jnb	.L784
	leaq	0(,%rdx,8), %rax
	subq	%rdx, %rax
	salq	$4, %rax
	addq	%rax, %rcx
	leaq	16(%rdi), %rax
	movq	%rax, (%rdi)
	movq	64(%rcx), %rsi
	movq	%rsi, %rdx
	addq	72(%rcx), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	%rbx, %rax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L783:
	.cfi_restore_state
	leaq	.LC34(%rip), %rcx
	movl	$75, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC36(%rip), %rdi
	call	__assert_fail@PLT
.L784:
	leaq	.LC5(%rip), %rcx
	leaq	.LC8(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
	.cfi_endproc
.LFE3752:
	.size	_Z14OrderGetStringB5cxx11i, .-_Z14OrderGetStringB5cxx11i
	.section	.rodata.str1.8
	.align 8
.LC37:
	.string	"std::string PositionGetString(int)"
	.section	.rodata.str1.1
.LC38:
	.string	"selectedPosition>=0"
	.text
	.globl	_Z17PositionGetStringB5cxx11i
	.type	_Z17PositionGetStringB5cxx11i, @function
_Z17PositionGetStringB5cxx11i:
.LFB3741:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movl	selectedPosition(%rip), %edx
	testl	%edx, %edx
	js	.L789
	movq	%rdi, %rbx
	movslq	%edx, %rdx
	movq	positions(%rip), %rcx
	movq	8+positions(%rip), %rax
	subq	%rcx, %rax
	sarq	$5, %rax
	movabsq	$-6148914691236517205, %rsi
	imulq	%rsi, %rax
	cmpq	%rax, %rdx
	jnb	.L790
	leaq	(%rdx,%rdx,2), %rax
	salq	$5, %rax
	addq	%rax, %rcx
	leaq	16(%rdi), %rax
	movq	%rax, (%rdi)
	movq	56(%rcx), %rsi
	movq	%rsi, %rdx
	addq	64(%rcx), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	%rbx, %rax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L789:
	.cfi_restore_state
	leaq	.LC37(%rip), %rcx
	movl	$70, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC38(%rip), %rdi
	call	__assert_fail@PLT
.L790:
	leaq	.LC5(%rip), %rcx
	leaq	.LC6(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
	.cfi_endproc
.LFE3741:
	.size	_Z17PositionGetStringB5cxx11i, .-_Z17PositionGetStringB5cxx11i
	.globl	_Z16StrategySLAnchor18ENUM_POSITION_TYPER9GridState
	.type	_Z16StrategySLAnchor18ENUM_POSITION_TYPER9GridState, @function
_Z16StrategySLAnchor18ENUM_POSITION_TYPER9GridState:
.LFB3910:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$48, %rsp
	.cfi_def_cfa_offset 80
	movl	%edi, %ebx
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	movq	96(%rsi), %rbp
	movq	%rsp, %rdi
	leaq	16(%rsp), %r12
	movq	%r12, (%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	(%rsp), %rdi
	cmpq	%r12, %rdi
	je	.L792
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L792:
	testl	%ebx, %ebx
	je	.L793
	pxor	%xmm0, %xmm0
	movq	%rbp, %xmm4
	comisd	%xmm4, %xmm0
	jnb	.L809
	cmpl	$1, %ebx
	jne	.L791
	movsd	InpGridSpacing(%rip), %xmm1
	movapd	%xmm1, %xmm2
	xorpd	.LC39(%rip), %xmm2
	movsd	.LC11(%rip), %xmm0
	movq	%rbp, %xmm6
	subsd	%xmm6, %xmm0
	comisd	%xmm0, %xmm2
	jbe	.L791
	addsd	.LC11(%rip), %xmm1
	movq	%xmm1, %rbp
	jmp	.L791
.L811:
	movsd	.LC10(%rip), %xmm0
	subsd	%xmm1, %xmm0
	movq	%xmm0, %rbp
	jmp	.L791
.L810:
	movq	.LC10(%rip), %rbp
	jmp	.L791
.L809:
	movq	.LC11(%rip), %rbp
	jmp	.L791
.L793:
	pxor	%xmm0, %xmm0
	movq	%rbp, %xmm3
	comisd	%xmm3, %xmm0
	jnb	.L810
	movsd	InpGridSpacing(%rip), %xmm1
	movsd	.LC10(%rip), %xmm0
	movq	%rbp, %xmm5
	subsd	%xmm5, %xmm0
	comisd	%xmm1, %xmm0
	ja	.L811
.L791:
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L812
	movq	%rbp, %xmm0
	addq	$48, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L812:
	.cfi_restore_state
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3910:
	.size	_Z16StrategySLAnchor18ENUM_POSITION_TYPER9GridState, .-_Z16StrategySLAnchor18ENUM_POSITION_TYPER9GridState
	.globl	_Z18StrategyPlanExistsR9GridState15ENUM_ORDER_TYPEd
	.type	_Z18StrategyPlanExistsR9GridState15ENUM_ORDER_TYPEd, @function
_Z18StrategyPlanExistsR9GridState15ENUM_ORDER_TYPEd:
.LFB3874:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$64, %rsp
	.cfi_def_cfa_offset 96
	movq	%rdi, %rbp
	movl	%esi, %ebx
	movsd	%xmm0, 8(%rsp)
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %r12
	movq	%r12, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%r12, %rdi
	je	.L814
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L814:
	movq	8(%rbp), %rax
	movq	16(%rbp), %rcx
	subq	%rax, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rdx
	imulq	%rdx, %rcx
	testl	%ecx, %ecx
	jle	.L820
	addq	$4, %rax
	leal	-1(%rcx), %edi
	movl	$0, %edx
	movsd	.LC40(%rip), %xmm1
	jmp	.L818
.L825:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L817:
	leaq	1(%rdx), %rsi
	addq	$240, %rax
	cmpq	%rdx, %rdi
	je	.L824
	movq	%rsi, %rdx
.L818:
	cmpq	%rdx, %rcx
	je	.L825
	cmpl	$1, (%rax)
	jne	.L817
	cmpl	%ebx, 8(%rax)
	jne	.L817
	movsd	20(%rax), %xmm0
	subsd	8(%rsp), %xmm0
	andpd	.LC0(%rip), %xmm0
	comisd	%xmm0, %xmm1
	jb	.L817
	movl	$1, %eax
	jmp	.L813
.L824:
	movl	$0, %eax
.L813:
	movq	56(%rsp), %rdx
	subq	%fs:40, %rdx
	jne	.L826
	addq	$64, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L820:
	.cfi_restore_state
	movl	$0, %eax
	jmp	.L813
.L826:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3874:
	.size	_Z18StrategyPlanExistsR9GridState15ENUM_ORDER_TYPEd, .-_Z18StrategyPlanExistsR9GridState15ENUM_ORDER_TYPEd
	.globl	_Z16FindPlannedOrderR9GridState15ENUM_ORDER_TYPEd
	.type	_Z16FindPlannedOrderR9GridState15ENUM_ORDER_TYPEd, @function
_Z16FindPlannedOrderR9GridState15ENUM_ORDER_TYPEd:
.LFB3840:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$64, %rsp
	.cfi_def_cfa_offset 96
	movq	%rdi, %rbp
	movl	%esi, %ebx
	movsd	%xmm0, 8(%rsp)
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %r12
	movq	%r12, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%r12, %rdi
	je	.L828
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L828:
	movq	8(%rbp), %rdx
	movq	16(%rbp), %rcx
	subq	%rdx, %rcx
	sarq	$4, %rcx
	movabsq	$-1229782938247303441, %rax
	imulq	%rax, %rcx
	testl	%ecx, %ecx
	jle	.L836
	addq	$4, %rdx
	leal	-1(%rcx), %edi
	movl	$0, %eax
	pxor	%xmm2, %xmm2
	movsd	.LC40(%rip), %xmm1
	jmp	.L834
.L841:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L832:
	subsd	8(%rsp), %xmm0
	andpd	.LC0(%rip), %xmm0
	comisd	%xmm0, %xmm1
	jnb	.L827
.L831:
	leaq	1(%rax), %rsi
	addq	$240, %rdx
	cmpq	%rax, %rdi
	je	.L840
	movq	%rsi, %rax
.L834:
	cmpq	%rax, %rcx
	je	.L841
	cmpl	$1, (%rdx)
	jne	.L831
	cmpl	%ebx, 8(%rdx)
	jne	.L831
	movsd	20(%rdx), %xmm0
	comisd	%xmm2, %xmm0
	ja	.L832
	movsd	68(%rdx), %xmm0
	jmp	.L832
.L840:
	movl	$-1, %eax
.L827:
	movq	56(%rsp), %rdx
	subq	%fs:40, %rdx
	jne	.L842
	addq	$64, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L836:
	.cfi_restore_state
	movl	$-1, %eax
	jmp	.L827
.L842:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3840:
	.size	_Z16FindPlannedOrderR9GridState15ENUM_ORDER_TYPEd, .-_Z16FindPlannedOrderR9GridState15ENUM_ORDER_TYPEd
	.section	.rodata.str1.8
	.align 8
.LC41:
	.string	"long int PositionGetInteger(int)"
	.section	.rodata.str1.1
.LC42:
	.string	"false"
	.text
	.globl	_Z18PositionGetIntegeri
	.type	_Z18PositionGetIntegeri, @function
_Z18PositionGetIntegeri:
.LFB3742:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$120, %rsp
	.cfi_def_cfa_offset 144
	movq	%fs:40, %rax
	movq	%rax, 104(%rsp)
	xorl	%eax, %eax
	movl	selectedPosition(%rip), %edx
	testl	%edx, %edx
	js	.L853
	movl	%edi, %ebp
	movslq	%edx, %rdx
	movq	positions(%rip), %rbx
	movq	8+positions(%rip), %rax
	subq	%rbx, %rax
	sarq	$5, %rax
	movabsq	$-6148914691236517205, %rcx
	imulq	%rcx, %rax
	cmpq	%rax, %rdx
	jnb	.L854
	leaq	(%rdx,%rdx,2), %rax
	salq	$5, %rax
	addq	%rax, %rbx
	movq	(%rbx), %rax
	movq	%rax, (%rsp)
	movq	8(%rbx), %rax
	movq	%rax, 8(%rsp)
	movsd	16(%rbx), %xmm0
	movsd	%xmm0, 16(%rsp)
	movsd	24(%rbx), %xmm0
	movsd	%xmm0, 24(%rsp)
	movsd	32(%rbx), %xmm0
	movsd	%xmm0, 32(%rsp)
	movsd	40(%rbx), %xmm0
	movsd	%xmm0, 40(%rsp)
	movl	48(%rbx), %eax
	movl	%eax, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 56(%rsp)
	movq	56(%rbx), %rsi
	movq	%rsi, %rdx
	addq	64(%rbx), %rdx
	leaq	56(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movl	88(%rbx), %eax
	movl	%eax, 88(%rsp)
	cmpl	$129, %ebp
	je	.L855
	movl	%eax, %ebx
	cmpl	$130, %ebp
	je	.L847
	cmpl	$135, %ebp
	jne	.L849
	movq	8(%rsp), %rbx
.L847:
	movq	56(%rsp), %rdi
	leaq	72(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L843
	movq	72(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L843:
	movq	104(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L856
	movq	%rbx, %rax
	addq	$120, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L853:
	.cfi_restore_state
	leaq	.LC41(%rip), %rcx
	movl	$71, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC38(%rip), %rdi
	call	__assert_fail@PLT
.L854:
	leaq	.LC5(%rip), %rcx
	leaq	.LC6(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L855:
	movslq	48(%rsp), %rbx
	jmp	.L847
.L849:
	leaq	.LC41(%rip), %rcx
	movl	$71, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC42(%rip), %rdi
	call	__assert_fail@PLT
.L856:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3742:
	.size	_Z18PositionGetIntegeri, .-_Z18PositionGetIntegeri
	.globl	_Z26CountLiveTerminalPositionsi
	.type	_Z26CountLiveTerminalPositionsi, @function
_Z26CountLiveTerminalPositionsi:
.LFB3848:
	.cfi_startproc
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$56, %rsp
	.cfi_def_cfa_offset 112
	movl	%edi, %r12d
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	call	_Z19GetMicrosecondCountv
	movq	%rax, %r13
	movl	$0, %ebx
	movl	$0, %ebp
	leaq	_ZL7_Symbol(%rip), %r14
	jmp	.L858
.L872:
	movq	_ZL7_Symbol(%rip), %rsi
	movq	(%rsp), %rdi
	testq	%rdx, %rdx
	je	.L861
	call	memcmp@PLT
	testl	%eax, %eax
	sete	%r15b
	jmp	.L860
.L871:
	movq	%r13, %rsi
	movl	$8, %edi
	call	_Z16Profiler30Recordim
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L870
	movl	%ebp, %eax
	addq	$56, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L861:
	.cfi_restore_state
	leaq	16(%rsp), %rax
	cmpq	%rax, %rdi
	jne	.L864
.L865:
	movl	$129, %edi
	call	_Z18PositionGetIntegeri
	movslq	%r12d, %rdx
	cmpq	%rax, %rdx
	sete	%al
	movzbl	%al, %eax
	addl	%eax, %ebp
.L859:
	addl	$1, %ebx
.L858:
	call	_Z14PositionsTotalv
	cmpl	%ebx, %eax
	jle	.L871
	movl	%ebx, %edi
	call	_Z17PositionGetTicketi
	testq	%rax, %rax
	je	.L859
	movq	%rax, %rdi
	call	_Z22PositionSelectByTicketm
	movl	%eax, %r15d
	testb	%al, %al
	je	.L859
	movq	%rsp, %rdi
	movl	$128, %esi
	call	_Z17PositionGetStringB5cxx11i
	movq	8(%rsp), %rdx
	cmpq	8(%r14), %rdx
	je	.L872
	movl	$0, %r15d
.L860:
	movq	(%rsp), %rdi
	leaq	16(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L862
.L864:
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L862:
	testb	%r15b, %r15b
	je	.L859
	jmp	.L865
.L870:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3848:
	.size	_Z26CountLiveTerminalPositionsi, .-_Z26CountLiveTerminalPositionsi
	.section	.rodata.str1.1
.LC43:
	.string	"long int OrderGetInteger(int)"
	.text
	.globl	_Z15OrderGetIntegeri
	.type	_Z15OrderGetIntegeri, @function
_Z15OrderGetIntegeri:
.LFB3753:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$136, %rsp
	.cfi_def_cfa_offset 160
	movq	%fs:40, %rax
	movq	%rax, 120(%rsp)
	xorl	%eax, %eax
	movl	selectedOrder(%rip), %edx
	testl	%edx, %edx
	js	.L883
	movl	%edi, %ebp
	movslq	%edx, %rdx
	movq	orders(%rip), %rbx
	movq	8+orders(%rip), %rax
	subq	%rbx, %rax
	sarq	$4, %rax
	movabsq	$7905747460161236407, %rcx
	imulq	%rcx, %rax
	cmpq	%rax, %rdx
	jnb	.L884
	leaq	0(,%rdx,8), %rax
	subq	%rdx, %rax
	salq	$4, %rax
	addq	%rax, %rbx
	movq	(%rbx), %rax
	movq	%rax, (%rsp)
	movl	8(%rbx), %eax
	movl	%eax, 8(%rsp)
	movsd	16(%rbx), %xmm0
	movsd	%xmm0, 16(%rsp)
	movsd	24(%rbx), %xmm0
	movsd	%xmm0, 24(%rsp)
	movsd	32(%rbx), %xmm0
	movsd	%xmm0, 32(%rsp)
	movsd	40(%rbx), %xmm0
	movsd	%xmm0, 40(%rsp)
	movsd	48(%rbx), %xmm0
	movsd	%xmm0, 48(%rsp)
	movl	56(%rbx), %eax
	movl	%eax, 56(%rsp)
	leaq	80(%rsp), %rax
	movq	%rax, 64(%rsp)
	movq	64(%rbx), %rsi
	movq	%rsi, %rdx
	addq	72(%rbx), %rdx
	leaq	64(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movl	96(%rbx), %eax
	movl	%eax, 96(%rsp)
	movq	104(%rbx), %rdx
	movq	%rdx, 104(%rsp)
	cmpl	$119, %ebp
	je	.L885
	movl	8(%rsp), %ebx
	cmpl	$120, %ebp
	je	.L877
	cmpl	$126, %ebp
	jne	.L879
	movl	%eax, %ebx
.L877:
	movq	64(%rsp), %rdi
	leaq	80(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L873
	movq	80(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L873:
	movq	120(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L886
	movq	%rbx, %rax
	addq	$136, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L883:
	.cfi_restore_state
	leaq	.LC43(%rip), %rcx
	movl	$76, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC36(%rip), %rdi
	call	__assert_fail@PLT
.L884:
	leaq	.LC5(%rip), %rcx
	leaq	.LC8(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L885:
	movslq	56(%rsp), %rbx
	jmp	.L877
.L879:
	leaq	.LC43(%rip), %rcx
	movl	$76, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC42(%rip), %rdi
	call	__assert_fail@PLT
.L886:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3753:
	.size	_Z15OrderGetIntegeri, .-_Z15OrderGetIntegeri
	.globl	_Z23CountLiveTerminalOrdersi
	.type	_Z23CountLiveTerminalOrdersi, @function
_Z23CountLiveTerminalOrdersi:
.LFB3849:
	.cfi_startproc
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$56, %rsp
	.cfi_def_cfa_offset 112
	movl	%edi, %ebp
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	call	_Z19GetMicrosecondCountv
	movq	%rax, %r12
	movl	$0, %ebx
	movl	$0, %r14d
	leaq	_ZL7_Symbol(%rip), %r13
	jmp	.L888
.L901:
	movq	_ZL7_Symbol(%rip), %rsi
	movq	(%rsp), %rdi
	testq	%rdx, %rdx
	je	.L891
	call	memcmp@PLT
	testl	%eax, %eax
	sete	%r15b
	jmp	.L890
.L889:
	addl	$1, %ebx
.L888:
	call	_Z11OrdersTotalv
	cmpl	%ebx, %eax
	jle	.L900
	movl	%ebx, %edi
	call	_Z14OrderGetTicketi
	testq	%rax, %rax
	je	.L889
	movq	%rax, %rdi
	call	_Z11OrderSelectm
	movl	%eax, %r15d
	testb	%al, %al
	je	.L889
	movq	%rsp, %rdi
	movl	$118, %esi
	call	_Z14OrderGetStringB5cxx11i
	movq	8(%rsp), %rdx
	cmpq	8(%r13), %rdx
	je	.L901
	movl	$0, %r15d
.L890:
	movq	(%rsp), %rdi
	leaq	16(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L892
.L894:
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L892:
	testb	%r15b, %r15b
	je	.L889
.L895:
	movl	$119, %edi
	call	_Z15OrderGetIntegeri
	movslq	%ebp, %rdx
	cmpq	%rax, %rdx
	jne	.L889
	movl	$120, %edi
	call	_Z15OrderGetIntegeri
	subl	$2, %eax
	cmpl	$6, %eax
	adcl	$0, %r14d
	jmp	.L889
.L900:
	movq	%r12, %rsi
	movl	$9, %edi
	call	_Z16Profiler30Recordim
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L902
	movl	%r14d, %eax
	addq	$56, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L891:
	.cfi_restore_state
	leaq	16(%rsp), %rax
	cmpq	%rax, %rdi
	jne	.L894
	jmp	.L895
.L902:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3849:
	.size	_Z23CountLiveTerminalOrdersi, .-_Z23CountLiveTerminalOrdersi
	.globl	_Z15CleanupFinishedR9GridState
	.type	_Z15CleanupFinishedR9GridState, @function
_Z15CleanupFinishedR9GridState:
.LFB3953:
	.cfi_startproc
	endbr64
	movl	$0, %eax
	cmpl	$4, (%rdi)
	jne	.L909
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	movzbl	connected(%rip), %eax
	testb	%al, %al
	je	.L903
	movq	16(%rdi), %rdx
	subq	8(%rdi), %rdx
	sarq	$4, %rdx
	imull	$-286331153, %edx, %edx
	movl	$0, %eax
	testl	%edx, %edx
	jle	.L912
.L903:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L912:
	.cfi_restore_state
	movl	32(%rdi), %edi
	call	_Z26CountLiveTerminalPositionsi
	movl	%eax, %edx
	movl	$0, %eax
	testl	%edx, %edx
	jne	.L903
	movl	32(%rbx), %edi
	call	_Z23CountLiveTerminalOrdersi
	testl	%eax, %eax
	sete	%al
	jmp	.L903
.L909:
	.cfi_def_cfa_offset 8
	.cfi_restore 3
	ret
	.cfi_endproc
.LFE3953:
	.size	_Z15CleanupFinishedR9GridState, .-_Z15CleanupFinishedR9GridState
	.globl	_Z19StrategyAlignVolumed
	.type	_Z19StrategyAlignVolumed, @function
_Z19StrategyAlignVolumed:
.LFB3869:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	subq	$64, %rsp
	.cfi_def_cfa_offset 80
	movsd	%xmm0, 8(%rsp)
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbx
	movq	%rbx, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L914
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L914:
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbx
	movq	%rbx, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L915
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L915:
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbx
	movq	%rbx, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L916
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L916:
	movsd	8(%rsp), %xmm1
	divsd	.LC9(%rip), %xmm1
	subsd	.LC44(%rip), %xmm1
	movapd	%xmm1, %xmm0
	movsd	.LC3(%rip), %xmm3
	movapd	%xmm1, %xmm2
	andpd	%xmm3, %xmm2
	movsd	.LC1(%rip), %xmm4
	ucomisd	%xmm2, %xmm4
	jbe	.L917
	cvttsd2siq	%xmm1, %rax
	pxor	%xmm2, %xmm2
	cvtsi2sdq	%rax, %xmm2
	cmpnlesd	%xmm2, %xmm0
	movsd	.LC2(%rip), %xmm4
	andpd	%xmm4, %xmm0
	addsd	%xmm2, %xmm0
	andnpd	%xmm1, %xmm3
	orpd	%xmm3, %xmm0
.L917:
	mulsd	.LC9(%rip), %xmm0
	movsd	.LC10(%rip), %xmm1
	comisd	%xmm0, %xmm1
	ja	.L928
	movsd	.LC10(%rip), %xmm0
.L913:
	movq	56(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L929
	addq	$64, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
.L928:
	.cfi_restore_state
	comisd	.LC9(%rip), %xmm0
	ja	.L913
	movsd	.LC9(%rip), %xmm0
	jmp	.L913
.L929:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3869:
	.size	_Z19StrategyAlignVolumed, .-_Z19StrategyAlignVolumed
	.globl	_Z18StrategyInitialLoti
	.type	_Z18StrategyInitialLoti, @function
_Z18StrategyInitialLoti:
.LFB3872:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	InpFixedLot(%rip), %rbx
	movl	InpInitialSizing(%rip), %eax
	cmpl	$1, %eax
	je	.L938
	cmpl	$2, %eax
	je	.L939
.L932:
	movq	%rbx, %xmm0
	call	_Z19StrategyAlignVolumed
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L938:
	.cfi_restore_state
	subl	$1, %edi
	pxor	%xmm0, %xmm0
	cvtsi2sdl	%edi, %xmm0
	mulsd	InpInitialLotStep(%rip), %xmm0
	movq	%rbx, %xmm2
	addsd	%xmm2, %xmm0
	minsd	InpInitialLotCap(%rip), %xmm0
	movq	%xmm0, %rbx
	jmp	.L932
.L939:
	subl	$1, %edi
	pxor	%xmm0, %xmm0
	cvtsi2sdl	%edi, %xmm0
	movsd	.LC45(%rip), %xmm1
	call	pow@PLT
	mulsd	InpInitialLotStep(%rip), %xmm0
	movq	%rbx, %xmm3
	addsd	%xmm3, %xmm0
	minsd	InpInitialLotCap(%rip), %xmm0
	movq	%xmm0, %rbx
	jmp	.L932
	.cfi_endproc
.LFE3872:
	.size	_Z18StrategyInitialLoti, .-_Z18StrategyInitialLoti
	.globl	_Z18StrategyRevisitLotR9GridStatedd
	.type	_Z18StrategyRevisitLotR9GridStatedd, @function
_Z18StrategyRevisitLotR9GridStatedd:
.LFB3886:
	.cfi_startproc
	endbr64
	subq	$24, %rsp
	.cfi_def_cfa_offset 32
	movsd	%xmm1, 8(%rsp)
	call	_Z19StrategyLevelVisitsR9GridStated
	movl	InpRevisitLotStyle(%rip), %edx
	cmpl	$1, %edx
	je	.L953
	cmpl	$2, %edx
	je	.L954
	cmpl	$3, %edx
	jne	.L944
	cmpl	$1, %eax
	jle	.L949
	addl	$2, %eax
	movsd	.LC2(%rip), %xmm0
	movapd	%xmm0, %xmm1
.L946:
	movapd	%xmm0, %xmm2
	addsd	%xmm1, %xmm0
	addl	$1, %edx
	movapd	%xmm2, %xmm1
	cmpl	%edx, %eax
	jne	.L946
.L945:
	mulsd	8(%rsp), %xmm0
	movsd	%xmm0, 8(%rsp)
	jmp	.L944
.L953:
	addl	$1, %eax
	pxor	%xmm0, %xmm0
	cvtsi2sdl	%eax, %xmm0
	mulsd	8(%rsp), %xmm0
	movsd	%xmm0, 8(%rsp)
.L944:
	movsd	InpRevisitLotMax(%rip), %xmm0
	minsd	8(%rsp), %xmm0
	call	_Z19StrategyAlignVolumed
	addq	$24, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L954:
	.cfi_restore_state
	pxor	%xmm0, %xmm0
	cvtsi2sdl	%eax, %xmm0
	mulsd	InpRevisitLotStep(%rip), %xmm0
	addsd	.LC2(%rip), %xmm0
	mulsd	8(%rsp), %xmm0
	movsd	%xmm0, 8(%rsp)
	jmp	.L944
.L949:
	movsd	.LC2(%rip), %xmm0
	jmp	.L945
	.cfi_endproc
.LFE3886:
	.size	_Z18StrategyRevisitLotR9GridStatedd, .-_Z18StrategyRevisitLotR9GridStatedd
	.globl	_Z28StrategyIncreaseOppositeLotsR9GridState
	.type	_Z28StrategyIncreaseOppositeLotsR9GridState, @function
_Z28StrategyIncreaseOppositeLotsR9GridState:
.LFB3889:
	.cfi_startproc
	endbr64
	cmpl	$1, InpLotIncreaseMode(%rip)
	jne	.L966
	pushq	%r14
	.cfi_def_cfa_offset 16
	.cfi_offset 14, -16
	pushq	%r13
	.cfi_def_cfa_offset 24
	.cfi_offset 13, -24
	pushq	%r12
	.cfi_def_cfa_offset 32
	.cfi_offset 12, -32
	pushq	%rbp
	.cfi_def_cfa_offset 40
	.cfi_offset 6, -40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset 3, -48
	subq	$16, %rsp
	.cfi_def_cfa_offset 64
	movq	%rdi, %rbp
	movsd	88(%rdi), %xmm0
	pxor	%xmm1, %xmm1
	comisd	%xmm0, %xmm1
	jnb	.L955
	addsd	%xmm0, %xmm0
	call	_Z19StrategyAlignVolumed
	movsd	%xmm0, 8(%rsp)
	movl	80(%rbp), %eax
	negl	%eax
	sbbl	%r12d, %r12d
	addl	$5, %r12d
	movq	8(%rbp), %rdx
	movq	16(%rbp), %rax
	subq	%rdx, %rax
	sarq	$4, %rax
	movabsq	$-1229782938247303441, %rcx
	imulq	%rcx, %rax
	movq	%rax, %rcx
	testl	%eax, %eax
	jle	.L955
	movl	$0, %ebx
	movl	$0, %r14d
	movabsq	$-1229782938247303441, %r13
	jmp	.L961
.L970:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L959:
	movq	8(%rbp), %rdx
	movq	16(%rbp), %rax
	subq	%rdx, %rax
	sarq	$4, %rax
	imulq	%r13, %rax
	movq	%rax, %rcx
	addq	$1, %rbx
	cmpl	%eax, %ebx
	jge	.L969
.L961:
	cmpq	%rcx, %rbx
	jnb	.L970
	movq	%rbx, %rax
	salq	$4, %rax
	subq	%rbx, %rax
	salq	$4, %rax
	addq	%rdx, %rax
	cmpl	%r12d, 12(%rax)
	setne	%dl
	cmpl	$1, 4(%rax)
	setne	%cl
	orb	%cl, %dl
	jne	.L959
	cmpl	$2, 112(%rax)
	je	.L959
	movsd	32(%rax), %xmm0
	movsd	80(%rax), %xmm1
	cmpb	$0, 104(%rax)
	je	.L960
	movapd	%xmm1, %xmm0
.L960:
	comisd	8(%rsp), %xmm0
	jnb	.L959
	movq	48(%rax), %rsi
	testq	%rsi, %rsi
	je	.L959
	movsd	24(%rax), %xmm0
	movsd	96(%rax), %xmm3
	movsd	88(%rax), %xmm2
	movsd	8(%rsp), %xmm1
	movq	%rbp, %rdi
	call	_Z19RequestReplaceOrderR9GridStatemdddd
	testb	%al, %al
	cmovne	%eax, %r14d
	jmp	.L959
.L969:
	testb	%r14b, %r14b
	je	.L955
	movsd	8(%rsp), %xmm5
	movsd	%xmm5, 144(%rbp)
.L955:
	addq	$16, %rsp
	.cfi_def_cfa_offset 48
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%rbp
	.cfi_def_cfa_offset 32
	popq	%r12
	.cfi_def_cfa_offset 24
	popq	%r13
	.cfi_def_cfa_offset 16
	popq	%r14
	.cfi_def_cfa_offset 8
	ret
.L966:
	.cfi_restore 3
	.cfi_restore 6
	.cfi_restore 12
	.cfi_restore 13
	.cfi_restore 14
	ret
	.cfi_endproc
.LFE3889:
	.size	_Z28StrategyIncreaseOppositeLotsR9GridState, .-_Z28StrategyIncreaseOppositeLotsR9GridState
	.section	.rodata.str1.1
.LC46:
	.string	"double PositionGetDouble(int)"
	.text
	.globl	_Z17PositionGetDoublei
	.type	_Z17PositionGetDoublei, @function
_Z17PositionGetDoublei:
.LFB3749:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$120, %rsp
	.cfi_def_cfa_offset 144
	movq	%fs:40, %rax
	movq	%rax, 104(%rsp)
	xorl	%eax, %eax
	movl	selectedPosition(%rip), %edx
	testl	%edx, %edx
	js	.L982
	movl	%edi, %ebp
	movslq	%edx, %rdx
	movq	positions(%rip), %rbx
	movq	8+positions(%rip), %rax
	subq	%rbx, %rax
	sarq	$5, %rax
	movabsq	$-6148914691236517205, %rcx
	imulq	%rcx, %rax
	cmpq	%rax, %rdx
	jnb	.L983
	leaq	(%rdx,%rdx,2), %rax
	salq	$5, %rax
	addq	%rax, %rbx
	movq	(%rbx), %rax
	movq	%rax, (%rsp)
	movq	8(%rbx), %rax
	movq	%rax, 8(%rsp)
	movsd	16(%rbx), %xmm0
	movsd	%xmm0, 16(%rsp)
	movsd	24(%rbx), %xmm0
	movsd	%xmm0, 24(%rsp)
	movsd	32(%rbx), %xmm0
	movsd	%xmm0, 32(%rsp)
	movsd	40(%rbx), %xmm0
	movsd	%xmm0, 40(%rsp)
	movl	48(%rbx), %eax
	movl	%eax, 48(%rsp)
	leaq	72(%rsp), %rax
	movq	%rax, 56(%rsp)
	movq	56(%rbx), %rsi
	movq	%rsi, %rdx
	addq	64(%rbx), %rdx
	leaq	56(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movl	88(%rbx), %eax
	movl	%eax, 88(%rsp)
	movq	16(%rsp), %rbx
	cmpl	$132, %ebp
	je	.L975
	movq	24(%rsp), %rbx
	cmpl	$131, %ebp
	je	.L975
	movq	32(%rsp), %rbx
	cmpl	$133, %ebp
	je	.L975
	cmpl	$134, %ebp
	jne	.L978
	movq	40(%rsp), %rbx
.L975:
	movq	56(%rsp), %rdi
	leaq	72(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L971
	movq	72(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L971:
	movq	104(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L984
	movq	%rbx, %xmm0
	addq	$120, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L982:
	.cfi_restore_state
	leaq	.LC46(%rip), %rcx
	movl	$72, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC38(%rip), %rdi
	call	__assert_fail@PLT
.L983:
	leaq	.LC5(%rip), %rcx
	leaq	.LC6(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L978:
	leaq	.LC46(%rip), %rcx
	movl	$72, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC42(%rip), %rdi
	call	__assert_fail@PLT
.L984:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3749:
	.size	_Z17PositionGetDoublei, .-_Z17PositionGetDoublei
	.section	.rodata.str1.1
.LC47:
	.string	"double OrderGetDouble(int)"
	.text
	.globl	_Z14OrderGetDoublei
	.type	_Z14OrderGetDoublei, @function
_Z14OrderGetDoublei:
.LFB3760:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$136, %rsp
	.cfi_def_cfa_offset 160
	movq	%fs:40, %rax
	movq	%rax, 120(%rsp)
	xorl	%eax, %eax
	movl	selectedOrder(%rip), %edx
	testl	%edx, %edx
	js	.L999
	movl	%edi, %ebp
	movslq	%edx, %rdx
	movq	orders(%rip), %rbx
	movq	8+orders(%rip), %rax
	subq	%rbx, %rax
	sarq	$4, %rax
	movabsq	$7905747460161236407, %rcx
	imulq	%rcx, %rax
	cmpq	%rax, %rdx
	jnb	.L1000
	leaq	0(,%rdx,8), %rax
	subq	%rdx, %rax
	salq	$4, %rax
	addq	%rax, %rbx
	movq	(%rbx), %rax
	movq	%rax, (%rsp)
	movl	8(%rbx), %eax
	movl	%eax, 8(%rsp)
	movsd	16(%rbx), %xmm0
	movsd	%xmm0, 16(%rsp)
	movsd	24(%rbx), %xmm0
	movsd	%xmm0, 24(%rsp)
	movsd	32(%rbx), %xmm0
	movsd	%xmm0, 32(%rsp)
	movsd	40(%rbx), %xmm0
	movsd	%xmm0, 40(%rsp)
	movsd	48(%rbx), %xmm0
	movsd	%xmm0, 48(%rsp)
	movl	56(%rbx), %eax
	movl	%eax, 56(%rsp)
	leaq	80(%rsp), %rax
	movq	%rax, 64(%rsp)
	movq	64(%rbx), %rsi
	movq	%rsi, %rdx
	addq	72(%rbx), %rdx
	leaq	64(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movl	96(%rbx), %eax
	movl	%eax, 96(%rsp)
	movq	104(%rbx), %rax
	movq	%rax, 104(%rsp)
	subl	$121, %ebp
	cmpl	$4, %ebp
	ja	.L988
	movl	%ebp, %ebp
	leaq	.L990(%rip), %rdx
	movslq	(%rdx,%rbp,4), %rax
	addq	%rdx, %rax
	notrack jmp	*%rax
	.section	.rodata
	.align 4
	.align 4
.L990:
	.long	.L994-.L990
	.long	.L993-.L990
	.long	.L992-.L990
	.long	.L991-.L990
	.long	.L989-.L990
	.text
.L999:
	leaq	.LC47(%rip), %rcx
	movl	$77, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC36(%rip), %rdi
	call	__assert_fail@PLT
.L1000:
	leaq	.LC5(%rip), %rcx
	leaq	.LC8(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L994:
	movq	16(%rsp), %rbx
.L995:
	movq	64(%rsp), %rdi
	leaq	80(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L985
	movq	80(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L985:
	movq	120(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1001
	movq	%rbx, %xmm0
	addq	$136, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L993:
	.cfi_restore_state
	movq	24(%rsp), %rbx
	jmp	.L995
.L992:
	movq	32(%rsp), %rbx
	jmp	.L995
.L991:
	movq	40(%rsp), %rbx
	jmp	.L995
.L989:
	movq	48(%rsp), %rbx
	jmp	.L995
.L988:
	leaq	.LC47(%rip), %rcx
	movl	$77, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC42(%rip), %rdi
	call	__assert_fail@PLT
.L1001:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3760:
	.size	_Z14OrderGetDoublei, .-_Z14OrderGetDoublei
	.globl	_Z18StrategySideProfit18ENUM_POSITION_TYPEdR9GridState
	.type	_Z18StrategySideProfit18ENUM_POSITION_TYPEdR9GridState, @function
_Z18StrategySideProfit18ENUM_POSITION_TYPEdR9GridState:
.LFB3908:
	.cfi_startproc
	endbr64
	pushq	%r13
	.cfi_def_cfa_offset 16
	.cfi_offset 13, -16
	pushq	%r12
	.cfi_def_cfa_offset 24
	.cfi_offset 12, -24
	pushq	%rbp
	.cfi_def_cfa_offset 32
	.cfi_offset 6, -32
	pushq	%rbx
	.cfi_def_cfa_offset 40
	.cfi_offset 3, -40
	subq	$72, %rsp
	.cfi_def_cfa_offset 112
	movl	%edi, %ebx
	movsd	%xmm0, 8(%rsp)
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	testl	%edi, %edi
	jne	.L1003
	movq	312(%rsi), %rbp
	movq	320(%rsi), %r12
.L1004:
	pxor	%xmm0, %xmm0
	movq	%rbp, %xmm2
	comisd	%xmm2, %xmm0
	jnb	.L1002
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %r13
	movq	%r13, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%r13, %rdi
	je	.L1006
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1006:
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %r13
	movq	%r13, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%r13, %rdi
	je	.L1007
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1007:
	testl	%ebx, %ebx
	jne	.L1008
	movsd	8(%rsp), %xmm0
	movq	%r12, %xmm4
	subsd	%xmm4, %xmm0
.L1009:
	divsd	.LC9(%rip), %xmm0
	movq	%rbp, %xmm3
	mulsd	%xmm3, %xmm0
	movq	%rbp, %xmm1
	mulsd	InpCommissionPerLot(%rip), %xmm1
	subsd	%xmm1, %xmm0
.L1002:
	movq	56(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1013
	addq	$72, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 40
	popq	%rbx
	.cfi_def_cfa_offset 32
	popq	%rbp
	.cfi_def_cfa_offset 24
	popq	%r12
	.cfi_def_cfa_offset 16
	popq	%r13
	.cfi_def_cfa_offset 8
	ret
.L1003:
	.cfi_restore_state
	movq	328(%rsi), %rbp
	movq	336(%rsi), %r12
	jmp	.L1004
.L1008:
	movq	%r12, %xmm0
	subsd	8(%rsp), %xmm0
	jmp	.L1009
.L1013:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3908:
	.size	_Z18StrategySideProfit18ENUM_POSITION_TYPEdR9GridState, .-_Z18StrategySideProfit18ENUM_POSITION_TYPEdR9GridState
	.section	.rodata.str1.8
	.align 8
.LC48:
	.string	"double HistoryOrderGetDouble(ulong, int)"
	.section	.rodata.str1.1
.LC49:
	.string	"historyOrders.count(t)"
.LC50:
	.string	"map::at"
	.text
	.globl	_Z21HistoryOrderGetDoublemi
	.type	_Z21HistoryOrderGetDoublemi, @function
_Z21HistoryOrderGetDoublemi:
.LFB3763:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$152, %rsp
	.cfi_def_cfa_offset 176
	movq	%rdi, 8(%rsp)
	movl	%esi, %ebp
	movq	%fs:40, %rax
	movq	%rax, 136(%rsp)
	xorl	%eax, %eax
	leaq	8(%rsp), %rsi
	leaq	historyOrders(%rip), %rdi
	call	_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_
	leaq	8+historyOrders(%rip), %rdx
	cmpq	%rax, %rdx
	je	.L1030
	movq	16+historyOrders(%rip), %rax
	testq	%rax, %rax
	je	.L1016
	movq	8(%rsp), %rdx
	leaq	8+historyOrders(%rip), %rbx
	jmp	.L1019
.L1030:
	leaq	.LC48(%rip), %rcx
	movl	$80, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC49(%rip), %rdi
	call	__assert_fail@PLT
.L1017:
	movq	24(%rax), %rax
.L1018:
	testq	%rax, %rax
	je	.L1031
.L1019:
	cmpq	%rdx, 32(%rax)
	jb	.L1017
	movq	%rax, %rbx
	movq	16(%rax), %rax
	jmp	.L1018
.L1031:
	leaq	8+historyOrders(%rip), %rax
	cmpq	%rax, %rbx
	je	.L1016
	cmpq	32(%rbx), %rdx
	jb	.L1016
	movq	40(%rbx), %rax
	movq	%rax, 16(%rsp)
	movl	48(%rbx), %eax
	movl	%eax, 24(%rsp)
	movsd	56(%rbx), %xmm0
	movsd	%xmm0, 32(%rsp)
	movsd	64(%rbx), %xmm0
	movsd	%xmm0, 40(%rsp)
	movsd	72(%rbx), %xmm0
	movsd	%xmm0, 48(%rsp)
	movsd	80(%rbx), %xmm0
	movsd	%xmm0, 56(%rsp)
	movsd	88(%rbx), %xmm0
	movsd	%xmm0, 64(%rsp)
	movl	96(%rbx), %eax
	movl	%eax, 72(%rsp)
	leaq	96(%rsp), %rax
	movq	%rax, 80(%rsp)
	movq	104(%rbx), %rsi
	movq	%rsi, %rdx
	addq	112(%rbx), %rdx
	leaq	80(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movl	136(%rbx), %eax
	movl	%eax, 112(%rsp)
	movq	144(%rbx), %rax
	movq	%rax, 120(%rsp)
	movq	32(%rsp), %rbx
	cmpl	$121, %ebp
	je	.L1023
	movq	48(%rsp), %rbx
	cmpl	$123, %ebp
	je	.L1023
	cmpl	$122, %ebp
	jne	.L1025
	movq	40(%rsp), %rbx
.L1023:
	movq	80(%rsp), %rdi
	leaq	96(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1014
	movq	96(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1014:
	movq	136(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1032
	movq	%rbx, %xmm0
	addq	$152, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L1016:
	.cfi_restore_state
	movq	136(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1033
	leaq	.LC50(%rip), %rdi
	call	_ZSt20__throw_out_of_rangePKc@PLT
.L1033:
	call	__stack_chk_fail@PLT
.L1025:
	leaq	.LC48(%rip), %rcx
	movl	$80, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC42(%rip), %rdi
	call	__assert_fail@PLT
.L1032:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3763:
	.size	_Z21HistoryOrderGetDoublemi, .-_Z21HistoryOrderGetDoublemi
	.section	.rodata.str1.8
	.align 8
.LC51:
	.string	"long int HistoryOrderGetInteger(ulong, int)"
	.text
	.globl	_Z22HistoryOrderGetIntegermi
	.type	_Z22HistoryOrderGetIntegermi, @function
_Z22HistoryOrderGetIntegermi:
.LFB3762:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$152, %rsp
	.cfi_def_cfa_offset 176
	movq	%rdi, 8(%rsp)
	movl	%esi, %ebp
	movq	%fs:40, %rax
	movq	%rax, 136(%rsp)
	xorl	%eax, %eax
	leaq	8(%rsp), %rsi
	leaq	historyOrders(%rip), %rdi
	call	_ZNKSt8_Rb_treeImSt4pairIKm5OrderESt10_Select1stIS3_ESt4lessImESaIS3_EE4findERS1_
	leaq	8+historyOrders(%rip), %rdx
	cmpq	%rax, %rdx
	je	.L1053
	movq	16+historyOrders(%rip), %rax
	testq	%rax, %rax
	je	.L1036
	movq	8(%rsp), %rdx
	leaq	8+historyOrders(%rip), %rbx
	jmp	.L1039
.L1053:
	leaq	.LC51(%rip), %rcx
	movl	$79, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC49(%rip), %rdi
	call	__assert_fail@PLT
.L1037:
	movq	24(%rax), %rax
.L1038:
	testq	%rax, %rax
	je	.L1054
.L1039:
	cmpq	%rdx, 32(%rax)
	jb	.L1037
	movq	%rax, %rbx
	movq	16(%rax), %rax
	jmp	.L1038
.L1054:
	leaq	8+historyOrders(%rip), %rax
	cmpq	%rax, %rbx
	je	.L1036
	cmpq	32(%rbx), %rdx
	jb	.L1036
	movq	40(%rbx), %rax
	movq	%rax, 16(%rsp)
	movl	48(%rbx), %eax
	movl	%eax, 24(%rsp)
	movsd	56(%rbx), %xmm0
	movsd	%xmm0, 32(%rsp)
	movsd	64(%rbx), %xmm0
	movsd	%xmm0, 40(%rsp)
	movsd	72(%rbx), %xmm0
	movsd	%xmm0, 48(%rsp)
	movsd	80(%rbx), %xmm0
	movsd	%xmm0, 56(%rsp)
	movsd	88(%rbx), %xmm0
	movsd	%xmm0, 64(%rsp)
	movl	96(%rbx), %eax
	movl	%eax, 72(%rsp)
	leaq	96(%rsp), %rax
	movq	%rax, 80(%rsp)
	movq	104(%rbx), %rsi
	movq	%rsi, %rdx
	addq	112(%rbx), %rdx
	leaq	80(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movl	136(%rbx), %edx
	movl	%edx, 112(%rsp)
	movq	144(%rbx), %rax
	movq	%rax, 120(%rsp)
	cmpl	$119, %ebp
	je	.L1055
	movl	24(%rsp), %ebx
	cmpl	$120, %ebp
	je	.L1043
	movl	%edx, %ebx
	cmpl	$126, %ebp
	je	.L1043
	cmpl	$127, %ebp
	jne	.L1046
	movq	%rax, %rbx
	testq	%rax, %rax
	jne	.L1043
	movl	$0, %ebx
	cmpl	$4, %edx
	jne	.L1043
	movq	16(%rsp), %rbx
	jmp	.L1043
.L1036:
	movq	136(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1056
	leaq	.LC50(%rip), %rdi
	call	_ZSt20__throw_out_of_rangePKc@PLT
.L1056:
	call	__stack_chk_fail@PLT
.L1055:
	movslq	72(%rsp), %rbx
.L1043:
	movq	80(%rsp), %rdi
	leaq	96(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1034
	movq	96(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1034:
	movq	136(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1057
	movq	%rbx, %rax
	addq	$152, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L1046:
	.cfi_restore_state
	leaq	.LC51(%rip), %rcx
	movl	$79, %edx
	leaq	.LC35(%rip), %rsi
	leaq	.LC42(%rip), %rdi
	call	__assert_fail@PLT
.L1057:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3762:
	.size	_Z22HistoryOrderGetIntegermi, .-_Z22HistoryOrderGetIntegermi
	.globl	_Z18StrategySLBrokerOK18ENUM_POSITION_TYPEd
	.type	_Z18StrategySLBrokerOK18ENUM_POSITION_TYPEd, @function
_Z18StrategySLBrokerOK18ENUM_POSITION_TYPEd:
.LFB3912:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$72, %rsp
	.cfi_def_cfa_offset 96
	movl	%edi, %ebx
	movsd	%xmm0, 8(%rsp)
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbp
	movq	%rbp, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbp, %rdi
	je	.L1059
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1059:
	testl	%ebx, %ebx
	jne	.L1060
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbp
	movq	%rbp, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movsd	.LC10(%rip), %xmm0
	comisd	8(%rsp), %xmm0
	setnb	%bl
	movq	16(%rsp), %rdi
	cmpq	%rbp, %rdi
	je	.L1058
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1058:
	movq	56(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1066
	movl	%ebx, %eax
	addq	$72, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L1060:
	.cfi_restore_state
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbp
	movq	%rbp, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movsd	8(%rsp), %xmm2
	comisd	.LC11(%rip), %xmm2
	setnb	%bl
	movq	16(%rsp), %rdi
	cmpq	%rbp, %rdi
	je	.L1058
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L1058
.L1066:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3912:
	.size	_Z18StrategySLBrokerOK18ENUM_POSITION_TYPEd, .-_Z18StrategySLBrokerOK18ENUM_POSITION_TYPEd
	.section	.text._ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_,"axG",@progbits,_ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_,comdat
	.align 2
	.weak	_ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_
	.type	_ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_, @function
_ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_:
.LFB5368:
	.cfi_startproc
	.cfi_personality 0x9b,DW.ref.__gxx_personality_v0
	.cfi_lsda 0x1b,.LLSDA5368
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$24, %rsp
	.cfi_def_cfa_offset 80
	movq	%rdx, %rbx
	movq	8(%rdi), %r13
	movq	(%rdi), %r15
	movq	%r13, %rax
	subq	%r15, %rax
	sarq	$4, %rax
	movabsq	$7905747460161236407, %rdx
	imulq	%rdx, %rax
	movabsq	$82351536043346212, %rdx
	cmpq	%rdx, %rax
	je	.L1110
	movq	%rdi, %r14
	movq	%rsi, %r12
	cmpq	%r15, %r13
	movl	$1, %edx
	cmovne	%rax, %rdx
	addq	%rdx, %rax
	jc	.L1070
	movabsq	$82351536043346212, %rdx
	cmpq	%rdx, %rax
	cmovbe	%rax, %rdx
	movq	%rdx, 8(%rsp)
	movq	%rsi, %rbp
	subq	%r15, %rbp
	movq	$0, (%rsp)
	testq	%rax, %rax
	je	.L1071
	jmp	.L1098
.L1110:
	leaq	.LC31(%rip), %rdi
.LEHB7:
	call	_ZSt20__throw_length_errorPKc@PLT
.LEHE7:
.L1116:
	movq	32(%rbx), %rax
	movq	%rax, 32(%rbp)
	movl	40(%rbx), %eax
	movl	%eax, 40(%rbp)
	movl	44(%rbx), %eax
	movl	%eax, 44(%rbp)
	movsd	48(%rbx), %xmm0
	movsd	%xmm0, 48(%rbp)
	movsd	56(%rbx), %xmm0
	movsd	%xmm0, 56(%rbp)
	movsd	64(%rbx), %xmm0
	movsd	%xmm0, 64(%rbp)
	movsd	72(%rbx), %xmm0
	movsd	%xmm0, 72(%rbp)
	movl	80(%rbx), %eax
	movl	%eax, 80(%rbp)
	movl	84(%rbx), %eax
	movl	%eax, 84(%rbp)
	movq	88(%rbx), %rax
	movq	%rax, 88(%rbp)
	movq	96(%rbx), %rax
	movq	%rax, 96(%rbp)
	movl	104(%rbx), %eax
	movl	%eax, 104(%rbp)
	cmpq	%r15, %r12
	je	.L1101
	leaq	16(%r15), %rbp
	movq	(%rsp), %rbx
	jmp	.L1082
.L1112:
	movq	-8(%rbp), %rdi
	leaq	1(%rdi), %rdx
	cmpl	$8, %edx
	jnb	.L1074
	testb	$4, %dl
	jne	.L1111
	testl	%edx, %edx
	je	.L1080
	movzbl	0(%rbp), %esi
	movb	%sil, (%rcx)
	testb	$2, %dl
	je	.L1080
	movl	%edx, %edx
	movzwl	-2(%rbp,%rdx), %esi
	movw	%si, -2(%rcx,%rdx)
	jmp	.L1080
.L1111:
	movl	0(%rbp), %esi
	movl	%esi, (%rcx)
	movl	%edx, %edx
	movl	-4(%rbp,%rdx), %esi
	movl	%esi, -4(%rcx,%rdx)
	jmp	.L1080
.L1074:
	movq	0(%rbp), %rsi
	movq	%rsi, (%rcx)
	movl	%edx, %esi
	movq	-8(%rbp,%rsi), %rdi
	movq	%rdi, -8(%rcx,%rsi)
	leaq	8(%rcx), %rsi
	andq	$-8, %rsi
	subq	%rsi, %rcx
	movq	%rbp, %rdi
	subq	%rcx, %rdi
	addl	%ecx, %edx
	andl	$-8, %edx
	cmpl	$8, %edx
	jb	.L1080
	andl	$-8, %edx
	movl	$0, %ecx
.L1078:
	movl	%ecx, %r8d
	movq	(%rdi,%r8), %r9
	movq	%r9, (%rsi,%r8)
	addl	$8, %ecx
	cmpl	%edx, %ecx
	jb	.L1078
	jmp	.L1080
.L1081:
	addq	$112, %rbx
	leaq	112(%rbp), %rax
	addq	$96, %rbp
	cmpq	%rbp, %r12
	je	.L1072
	movq	%rax, %rbp
.L1082:
	leaq	16(%rbx), %rcx
	movq	%rcx, (%rbx)
	movq	%rbp, %rax
	movq	-16(%rbp), %rdx
	cmpq	%rbp, %rdx
	je	.L1112
	movq	%rdx, (%rbx)
	movq	0(%rbp), %rdx
	movq	%rdx, 16(%rbx)
.L1080:
	movq	-8(%rax), %rdx
	movq	%rdx, 8(%rbx)
	movq	%rax, -16(%rax)
	movq	$0, -8(%rax)
	movb	$0, (%rax)
	movq	16(%rax), %rdx
	movq	%rdx, 32(%rbx)
	movl	24(%rax), %edx
	movl	%edx, 40(%rbx)
	movl	28(%rax), %edx
	movl	%edx, 44(%rbx)
	movsd	32(%rax), %xmm0
	movsd	%xmm0, 48(%rbx)
	movsd	40(%rax), %xmm0
	movsd	%xmm0, 56(%rbx)
	movsd	48(%rax), %xmm0
	movsd	%xmm0, 64(%rbx)
	movsd	56(%rax), %xmm0
	movsd	%xmm0, 72(%rbx)
	movl	64(%rax), %edx
	movl	%edx, 80(%rbx)
	movl	68(%rax), %edx
	movl	%edx, 84(%rbx)
	movq	72(%rax), %rdx
	movq	%rdx, 88(%rbx)
	movq	80(%rax), %rdx
	movq	%rdx, 96(%rbx)
	movl	88(%rax), %edx
	movl	%edx, 104(%rbx)
	movq	-16(%rax), %rdi
	cmpq	%rax, %rdi
	je	.L1081
	movq	(%rax), %rsi
	addq	$1, %rsi
	call	_ZdlPvm@PLT
	jmp	.L1081
.L1101:
	movq	(%rsp), %rbx
.L1072:
	addq	$112, %rbx
	cmpq	%r13, %r12
	je	.L1083
	movq	%r12, %rax
	movq	%rbx, %rdx
	jmp	.L1092
.L1115:
	movq	8(%rax), %rcx
	addq	$1, %rcx
	cmpl	$8, %ecx
	jnb	.L1085
	testb	$4, %cl
	jne	.L1113
	testl	%ecx, %ecx
	je	.L1091
	movzbl	(%rdi), %r8d
	movb	%r8b, (%rsi)
	testb	$2, %cl
	je	.L1091
	movl	%ecx, %ecx
	movzwl	-2(%rdi,%rcx), %edi
	movw	%di, -2(%rsi,%rcx)
	jmp	.L1091
.L1113:
	movl	(%rdi), %r8d
	movl	%r8d, (%rsi)
	movl	%ecx, %ecx
	movl	-4(%rdi,%rcx), %edi
	movl	%edi, -4(%rsi,%rcx)
	jmp	.L1091
.L1085:
	movq	(%rdi), %r8
	movq	%r8, (%rsi)
	movl	%ecx, %r8d
	movq	-8(%rdi,%r8), %r9
	movq	%r9, -8(%rsi,%r8)
	leaq	8(%rsi), %r8
	andq	$-8, %r8
	subq	%r8, %rsi
	subq	%rsi, %rdi
	addl	%esi, %ecx
	andl	$-8, %ecx
	cmpl	$8, %ecx
	jb	.L1091
	andl	$-8, %ecx
	movl	$0, %esi
.L1089:
	movl	%esi, %r9d
	movq	(%rdi,%r9), %r10
	movq	%r10, (%r8,%r9)
	addl	$8, %esi
	cmpl	%ecx, %esi
	jb	.L1089
.L1091:
	movq	8(%rax), %rcx
	movq	%rcx, 8(%rdx)
	movq	32(%rax), %rcx
	movq	%rcx, 32(%rdx)
	movl	40(%rax), %ecx
	movl	%ecx, 40(%rdx)
	movl	44(%rax), %ecx
	movl	%ecx, 44(%rdx)
	movsd	48(%rax), %xmm0
	movsd	%xmm0, 48(%rdx)
	movsd	56(%rax), %xmm0
	movsd	%xmm0, 56(%rdx)
	movsd	64(%rax), %xmm0
	movsd	%xmm0, 64(%rdx)
	movsd	72(%rax), %xmm0
	movsd	%xmm0, 72(%rdx)
	movl	80(%rax), %ecx
	movl	%ecx, 80(%rdx)
	movl	84(%rax), %ecx
	movl	%ecx, 84(%rdx)
	movq	88(%rax), %rcx
	movq	%rcx, 88(%rdx)
	movq	96(%rax), %rcx
	movq	%rcx, 96(%rdx)
	movl	104(%rax), %ecx
	movl	%ecx, 104(%rdx)
	addq	$112, %rax
	addq	$112, %rdx
	cmpq	%rax, %r13
	je	.L1114
.L1092:
	leaq	16(%rdx), %rsi
	movq	%rsi, (%rdx)
	movq	(%rax), %rcx
	leaq	16(%rax), %rdi
	cmpq	%rdi, %rcx
	je	.L1115
	movq	%rcx, (%rdx)
	movq	16(%rax), %rcx
	movq	%rcx, 16(%rdx)
	jmp	.L1091
.L1114:
	subq	%r12, %r13
	leaq	-112(%r13), %rax
	shrq	$4, %rax
	movabsq	$988218432520154551, %rdx
	imulq	%rdx, %rax
	movabsq	$1152921504606846975, %rdx
	andq	%rdx, %rax
	addq	$1, %rax
	leaq	0(,%rax,8), %rdx
	subq	%rax, %rdx
	movq	%rdx, %rax
	salq	$4, %rax
	addq	%rax, %rbx
.L1083:
	testq	%r15, %r15
	je	.L1093
	movq	16(%r14), %rsi
	subq	%r15, %rsi
	movq	%r15, %rdi
	call	_ZdlPvm@PLT
.L1093:
	movq	(%rsp), %rdi
	movq	%rdi, (%r14)
	movq	%rbx, 8(%r14)
	movq	8(%rsp), %rsi
	leaq	0(,%rsi,8), %rax
	subq	%rsi, %rax
	salq	$4, %rax
	addq	%rdi, %rax
	movq	%rax, 16(%r14)
	addq	$24, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L1103:
	.cfi_restore_state
	endbr64
	movq	%rax, %rdi
	call	__cxa_begin_catch@PLT
	cmpq	$0, (%rsp)
	jne	.L1095
	movq	%rbp, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1096:
.LEHB8:
	call	__cxa_rethrow@PLT
.LEHE8:
.L1104:
	endbr64
	movq	%rax, %rbx
	call	__cxa_end_catch@PLT
	movq	%rbx, %rdi
.LEHB9:
	call	_Unwind_Resume@PLT
.L1095:
	imulq	$112, 8(%rsp), %rsi
	movq	(%rsp), %rdi
	call	_ZdlPvm@PLT
	jmp	.L1096
.L1070:
	movq	%rsi, %rbp
	subq	%r15, %rbp
	movabsq	$82351536043346212, %rax
	movq	%rax, 8(%rsp)
.L1098:
	movq	8(%rsp), %rax
	leaq	0(,%rax,8), %rdi
	subq	%rax, %rdi
	salq	$4, %rdi
	call	_Znwm@PLT
.LEHE9:
	movq	%rax, (%rsp)
.L1071:
	movq	(%rsp), %rax
	addq	%rax, %rbp
	leaq	16(%rbp), %rax
	movq	%rax, 0(%rbp)
	movq	(%rbx), %rsi
	movq	%rsi, %rdx
	addq	8(%rbx), %rdx
	movq	%rbp, %rdi
.LEHB10:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE10:
	jmp	.L1116
	.cfi_endproc
.LFE5368:
	.section	.gcc_except_table
	.align 4
.LLSDA5368:
	.byte	0xff
	.byte	0x9b
	.uleb128 .LLSDATT5368-.LLSDATTD5368
.LLSDATTD5368:
	.byte	0x1
	.uleb128 .LLSDACSE5368-.LLSDACSB5368
.LLSDACSB5368:
	.uleb128 .LEHB7-.LFB5368
	.uleb128 .LEHE7-.LEHB7
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB8-.LFB5368
	.uleb128 .LEHE8-.LEHB8
	.uleb128 .L1104-.LFB5368
	.uleb128 0
	.uleb128 .LEHB9-.LFB5368
	.uleb128 .LEHE9-.LEHB9
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB10-.LFB5368
	.uleb128 .LEHE10-.LEHB10
	.uleb128 .L1103-.LFB5368
	.uleb128 0x1
.LLSDACSE5368:
	.byte	0x1
	.byte	0
	.align 4
	.long	0

.LLSDATT5368:
	.section	.text._ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_,"axG",@progbits,_ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_,comdat
	.size	_ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_, .-_ZNSt6vectorI15MqlTradeRequestSaIS0_EE17_M_realloc_insertIJRKS0_EEEvN9__gnu_cxx17__normal_iteratorIPS0_S2_EEDpOT_
	.text
	.globl	_Z15StrategyNetAtSL18ENUM_POSITION_TYPEdR9GridState
	.type	_Z15StrategyNetAtSL18ENUM_POSITION_TYPEdR9GridState, @function
_Z15StrategyNetAtSL18ENUM_POSITION_TYPEdR9GridState:
.LFB3909:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$64, %rsp
	.cfi_def_cfa_offset 96
	movl	%edi, %ebp
	movq	%rsi, %rbx
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	call	_Z18StrategySideProfit18ENUM_POSITION_TYPEdR9GridState
	movsd	%xmm0, 8(%rsp)
	testl	%ebp, %ebp
	je	.L1118
	movsd	312(%rbx), %xmm1
	pxor	%xmm0, %xmm0
	comisd	%xmm0, %xmm1
	jbe	.L1117
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %r12
	movq	%r12, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%r12, %rdi
	je	.L1122
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1122:
	movsd	.LC10(%rip), %xmm0
	jmp	.L1125
.L1118:
	movsd	328(%rbx), %xmm1
	pxor	%xmm0, %xmm0
	comisd	%xmm0, %xmm1
	jbe	.L1117
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %r12
	movq	%r12, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%r12, %rdi
	je	.L1124
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1124:
	movsd	.LC11(%rip), %xmm0
.L1125:
	testl	%ebp, %ebp
	sete	%dil
	movzbl	%dil, %edi
	movq	%rbx, %rsi
	call	_Z18StrategySideProfit18ENUM_POSITION_TYPEdR9GridState
	addsd	8(%rsp), %xmm0
	movsd	%xmm0, 8(%rsp)
.L1117:
	movq	56(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1129
	movsd	8(%rsp), %xmm0
	addq	$64, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L1129:
	.cfi_restore_state
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3909:
	.size	_Z15StrategyNetAtSL18ENUM_POSITION_TYPEdR9GridState, .-_Z15StrategyNetAtSL18ENUM_POSITION_TYPEdR9GridState
	.globl	_Z19StrategySLCandidateR9GridState18ENUM_POSITION_TYPE12ENUM_SL_MODE
	.type	_Z19StrategySLCandidateR9GridState18ENUM_POSITION_TYPE12ENUM_SL_MODE, @function
_Z19StrategySLCandidateR9GridState18ENUM_POSITION_TYPE12ENUM_SL_MODE:
.LFB3913:
	.cfi_startproc
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$72, %rsp
	.cfi_def_cfa_offset 128
	movq	%rdi, %r15
	movl	%esi, %ebp
	movl	%edx, %r12d
	movq	%fs:40, %rax
	movq	%rax, 56(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbx
	movq	%rbx, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L1131
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1131:
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbx
	movq	%rbx, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L1132
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1132:
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rbx
	movq	%rbx, 16(%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	16(%rsp), %rdi
	cmpq	%rbx, %rdi
	je	.L1133
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1133:
	movq	%r15, %rsi
	movl	%ebp, %edi
	call	_Z16StrategySLAnchor18ENUM_POSITION_TYPER9GridState
	movsd	%xmm0, 8(%rsp)
	movq	352(%r15), %r13
	movl	InpSLNBack(%rip), %esi
	movl	$1, %edi
	call	_Z7MathMaxIiiEDaT_T0_
	cmpl	$1, %r12d
	je	.L1152
	cvttsd2sil	%xmm0, %ebx
	cmpl	$4, %r12d
	je	.L1149
	cmpl	$2, %r12d
	je	.L1150
	movl	%ebx, %r14d
	movl	$1, %r12d
	movl	$1, %ebx
	jmp	.L1138
.L1152:
	movq	.LC11(%rip), %rbx
	testl	%ebp, %ebp
	jne	.L1135
	movq	.LC10(%rip), %rbx
.L1135:
	movq	%r13, %xmm1
	movq	%rbx, %xmm0
	movl	%ebp, %edi
	call	_Z20StrategySLIsProgress18ENUM_POSITION_TYPEdd
	movq	$0x000000000, (%rsp)
	testb	%al, %al
	je	.L1130
	movq	%rbx, %xmm0
	movl	%ebp, %edi
	call	_Z18StrategySLBrokerOK18ENUM_POSITION_TYPEd
	movq	$0x000000000, (%rsp)
	testb	%al, %al
	je	.L1130
	movq	%r15, %rsi
	movq	%rbx, %xmm0
	movl	%ebp, %edi
	call	_Z15StrategyNetAtSL18ENUM_POSITION_TYPEdR9GridState
	movq	$0x000000000, (%rsp)
	pxor	%xmm1, %xmm1
	comisd	%xmm0, %xmm1
	ja	.L1130
	movq	%rbx, %xmm0
	call	_Z18StrategyAlignPriced
	movsd	%xmm0, (%rsp)
	jmp	.L1130
.L1149:
	movl	$-1, %r12d
	movl	$1, %r14d
	jmp	.L1138
.L1150:
	movl	$1, %r12d
	movl	$1, %ebx
	movl	$1, %r14d
	jmp	.L1138
.L1139:
	leal	-1(%rbx), %eax
	pxor	%xmm0, %xmm0
	cvtsi2sdl	%eax, %xmm0
	mulsd	InpGridSpacing(%rip), %xmm0
	addsd	8(%rsp), %xmm0
	jmp	.L1140
.L1141:
	addl	%r12d, %ebx
.L1138:
	testl	%r12d, %r12d
	jle	.L1142
	cmpl	%ebx, %r14d
	jl	.L1153
.L1143:
	testl	%ebp, %ebp
	jne	.L1139
	leal	-1(%rbx), %eax
	pxor	%xmm1, %xmm1
	cvtsi2sdl	%eax, %xmm1
	mulsd	InpGridSpacing(%rip), %xmm1
	movsd	8(%rsp), %xmm0
	subsd	%xmm1, %xmm0
.L1140:
	call	_Z18StrategyAlignPriced
	movq	%r13, %xmm1
	movsd	%xmm0, (%rsp)
	movl	%ebp, %edi
	call	_Z20StrategySLIsProgress18ENUM_POSITION_TYPEdd
	testb	%al, %al
	je	.L1141
	movsd	(%rsp), %xmm0
	movl	%ebp, %edi
	call	_Z18StrategySLBrokerOK18ENUM_POSITION_TYPEd
	testb	%al, %al
	je	.L1141
	movq	%r15, %rsi
	movsd	(%rsp), %xmm0
	movl	%ebp, %edi
	call	_Z15StrategyNetAtSL18ENUM_POSITION_TYPEdR9GridState
	pxor	%xmm3, %xmm3
	comisd	%xmm3, %xmm0
	jb	.L1141
	jmp	.L1130
.L1153:
	movq	$0x000000000, (%rsp)
.L1130:
	movq	56(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1154
	movsd	(%rsp), %xmm0
	addq	$72, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L1142:
	.cfi_restore_state
	cmpl	%ebx, %r14d
	jle	.L1143
	movq	$0x000000000, (%rsp)
	jmp	.L1130
.L1154:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3913:
	.size	_Z19StrategySLCandidateR9GridState18ENUM_POSITION_TYPE12ENUM_SL_MODE, .-_Z19StrategySLCandidateR9GridState18ENUM_POSITION_TYPE12ENUM_SL_MODE
	.globl	_Z21StrategyRefreshBasketR9GridState
	.type	_Z21StrategyRefreshBasketR9GridState, @function
_Z21StrategyRefreshBasketR9GridState:
.LFB3907:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$56, %rsp
	.cfi_def_cfa_offset 80
	movq	%rdi, %rbx
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	movq	%rsp, %rdi
	leaq	16(%rsp), %rbp
	movq	%rbp, (%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	(%rsp), %rdi
	cmpq	%rbp, %rdi
	je	.L1156
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1156:
	movq	%rsp, %rdi
	leaq	16(%rsp), %rbp
	movq	%rbp, (%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	(%rsp), %rdi
	cmpq	%rbp, %rdi
	je	.L1157
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1157:
	movq	%rsp, %rdi
	leaq	16(%rsp), %rbp
	movq	%rbp, (%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	(%rsp), %rdi
	cmpq	%rbp, %rdi
	je	.L1158
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1158:
	movq	$0x000000000, 312(%rbx)
	movq	$0x000000000, 328(%rbx)
	movq	8(%rbx), %rax
	movq	16(%rbx), %rdx
	subq	%rax, %rdx
	sarq	$4, %rdx
	movabsq	$-1229782938247303441, %rcx
	imulq	%rcx, %rdx
	testl	%edx, %edx
	jle	.L1168
	addq	$4, %rax
	leal	-1(%rdx), %edi
	movl	$0, %ecx
	pxor	%xmm2, %xmm2
	movapd	%xmm2, %xmm5
	jmp	.L1163
.L1178:
	leaq	.LC5(%rip), %rcx
	leaq	.LC21(%rip), %rdx
	movl	$1128, %esi
	leaq	.LC7(%rip), %rdi
	call	_ZSt21__glibcxx_assert_failPKciS0_S0_@PLT
.L1162:
	movapd	%xmm1, %xmm3
	addsd	328(%rbx), %xmm3
	movsd	%xmm3, 328(%rbx)
	mulsd	%xmm1, %xmm0
	addsd	%xmm0, %xmm2
.L1161:
	leaq	1(%rcx), %rsi
	addq	$240, %rax
	cmpq	%rdi, %rcx
	je	.L1177
	movq	%rsi, %rcx
.L1163:
	cmpq	%rdx, %rcx
	je	.L1178
	cmpl	$2, (%rax)
	jne	.L1161
	cmpb	$0, 100(%rax)
	je	.L1161
	movsd	68(%rax), %xmm0
	movsd	76(%rax), %xmm1
	cmpl	$0, 4(%rax)
	jne	.L1162
	movapd	%xmm1, %xmm3
	addsd	312(%rbx), %xmm3
	movsd	%xmm3, 312(%rbx)
	mulsd	%xmm1, %xmm0
	addsd	%xmm0, %xmm5
	jmp	.L1161
.L1177:
	movsd	312(%rbx), %xmm4
	pxor	%xmm0, %xmm0
	comisd	%xmm0, %xmm4
	jbe	.L1174
	divsd	%xmm4, %xmm5
.L1159:
	movsd	%xmm5, 320(%rbx)
	movsd	328(%rbx), %xmm3
	pxor	%xmm0, %xmm0
	comisd	%xmm0, %xmm3
	jbe	.L1175
	divsd	%xmm3, %xmm2
.L1165:
	movsd	%xmm2, 336(%rbx)
	movsd	.LC10(%rip), %xmm1
	movapd	%xmm1, %xmm0
	subsd	%xmm5, %xmm0
	mulsd	%xmm1, %xmm0
	mulsd	%xmm4, %xmm0
	movsd	%xmm0, 296(%rbx)
	subsd	.LC11(%rip), %xmm2
	mulsd	%xmm1, %xmm2
	mulsd	%xmm3, %xmm2
	movsd	%xmm2, 304(%rbx)
	addsd	%xmm2, %xmm0
	movsd	%xmm0, 280(%rbx)
	addsd	%xmm4, %xmm3
	mulsd	InpCommissionPerLot(%rip), %xmm3
	subsd	%xmm3, %xmm0
	movsd	%xmm0, 288(%rbx)
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1179
	addq	$56, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L1168:
	.cfi_restore_state
	pxor	%xmm2, %xmm2
	movapd	%xmm2, %xmm4
	movapd	%xmm2, %xmm5
	jmp	.L1159
.L1174:
	pxor	%xmm5, %xmm5
	jmp	.L1159
.L1175:
	pxor	%xmm2, %xmm2
	jmp	.L1165
.L1179:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3907:
	.size	_Z21StrategyRefreshBasketR9GridState, .-_Z21StrategyRefreshBasketR9GridState
	.section	.text._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag,"axG",@progbits,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag,comdat
	.align 2
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag
	.type	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag, @function
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag:
.LFB5221:
	.cfi_startproc
	endbr64
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$16, %rsp
	.cfi_def_cfa_offset 48
	movq	%rdi, %rbx
	movq	%rsi, %r12
	movq	%fs:40, %rax
	movq	%rax, 8(%rsp)
	xorl	%eax, %eax
	subq	%rsi, %rdx
	movq	%rdx, %rbp
	movq	%rdx, (%rsp)
	cmpq	$15, %rdx
	ja	.L1187
	movq	(%rdi), %rdi
	cmpq	$1, %rdx
	jne	.L1183
	movzbl	(%rsi), %eax
	movb	%al, (%rdi)
.L1184:
	movq	(%rsp), %rax
	movq	%rax, 8(%rbx)
	movq	(%rbx), %rdx
	movb	$0, (%rdx,%rax)
	movq	8(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1188
	addq	$16, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
.L1187:
	.cfi_restore_state
	movq	%rsp, %rsi
	movl	$0, %edx
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm
	movq	%rax, %rdi
	movq	%rax, (%rbx)
	movq	(%rsp), %rax
	movq	%rax, 16(%rbx)
.L1182:
	movq	%rbp, %rdx
	movq	%r12, %rsi
	call	memcpy@PLT
	jmp	.L1184
.L1183:
	testq	%rdx, %rdx
	je	.L1184
	jmp	.L1182
.L1188:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE5221:
	.size	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag, .-_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag
	.section	.rodata._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_.str1.8,"aMS",@progbits,1
	.align 8
.LC52:
	.string	"basic_string: construction from null is not valid"
	.section	.text._ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_,"axG",@progbits,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC5IS3_EEPKcRKS3_,comdat
	.align 2
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_
	.type	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_, @function
_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_:
.LFB4925:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$8, %rsp
	.cfi_def_cfa_offset 32
	leaq	16(%rdi), %rax
	movq	%rax, (%rdi)
	testq	%rsi, %rsi
	je	.L1192
	movq	%rdi, %rbp
	movq	%rsi, %rbx
	movq	%rsi, %rdi
	call	strlen@PLT
	leaq	(%rbx,%rax), %rdx
	movq	%rbx, %rsi
	movq	%rbp, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
.L1192:
	.cfi_restore_state
	leaq	.LC52(%rip), %rdi
	call	_ZSt19__throw_logic_errorPKc@PLT
	.cfi_endproc
.LFE4925:
	.size	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_, .-_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_
	.weak	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1IS3_EEPKcRKS3_
	.set	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1IS3_EEPKcRKS3_,_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEPKcRKS3_
	.section	.rodata.str1.1
.LC53:
	.string	"basic_string::substr"
	.section	.rodata.str1.8
	.align 8
.LC54:
	.string	"%s: __pos (which is %zu) > this->size() (which is %zu)"
	.section	.rodata.str1.1
.LC55:
	.string	"basic_string::basic_string"
	.text
	.globl	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.type	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, @function
_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii:
.LFB3806:
	.cfi_startproc
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movslq	%edx, %rdx
	movq	8(%rsi), %rax
	cmpq	%rdx, %rax
	jb	.L1197
	movq	%rdi, %rbx
	movslq	%ecx, %rcx
	leaq	16(%rdi), %rax
	movq	%rax, (%rdi)
	movq	(%rsi), %rdi
	movq	8(%rsi), %rax
	cmpq	%rdx, %rax
	jb	.L1198
	leaq	(%rdi,%rdx), %rsi
	subq	%rdx, %rax
	cmpq	%rcx, %rax
	cmova	%rcx, %rax
	leaq	(%rsi,%rax), %rdx
	movq	%rbx, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag
	movq	%rbx, %rax
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L1197:
	.cfi_restore_state
	movq	%rax, %rcx
	leaq	.LC53(%rip), %rsi
	leaq	.LC54(%rip), %rdi
	movl	$0, %eax
	call	_ZSt24__throw_out_of_range_fmtPKcz@PLT
.L1198:
	movq	%rax, %rcx
	leaq	.LC55(%rip), %rsi
	leaq	.LC54(%rip), %rdi
	movl	$0, %eax
	call	_ZSt24__throw_out_of_range_fmtPKcz@PLT
	.cfi_endproc
.LFE3806:
	.size	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii, .-_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
	.globl	_Z15GetSymbolCode30NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.type	_Z15GetSymbolCode30NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, @function
_Z15GetSymbolCode30NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE:
.LFB3826:
	.cfi_startproc
	.cfi_personality 0x9b,DW.ref.__gxx_personality_v0
	.cfi_lsda 0x1b,.LLSDA3826
	endbr64
	pushq	%r13
	.cfi_def_cfa_offset 16
	.cfi_offset 13, -16
	pushq	%r12
	.cfi_def_cfa_offset 24
	.cfi_offset 12, -24
	pushq	%rbp
	.cfi_def_cfa_offset 32
	.cfi_offset 6, -32
	pushq	%rbx
	.cfi_def_cfa_offset 40
	.cfi_offset 3, -40
	subq	$152, %rsp
	.cfi_def_cfa_offset 192
	movq	%fs:40, %rax
	movq	%rax, 136(%rsp)
	xorl	%eax, %eax
	movq	%rsp, %rbx
	leaq	16(%rsp), %rax
	movq	%rax, (%rsp)
	movq	(%rdi), %rsi
	movq	%rsi, %rdx
	addq	8(%rdi), %rdx
	movq	%rbx, %rdi
.LEHB11:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE11:
	movq	%rbx, %rdi
	call	_Z13StringToUpperRNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	leaq	32(%rsp), %rdi
	leaq	48(%rsp), %rax
	movq	%rax, 32(%rsp)
	movq	(%rsp), %rsi
	movq	%rsi, %rdx
	addq	8(%rsp), %rdx
.LEHB12:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE12:
	movl	$0, %ebx
	cmpl	$0, 40(%rsp)
	jg	.L1253
.L1239:
	movq	32(%rsp), %rdi
	leaq	48(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1209
	movq	48(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1209:
	testb	%bl, %bl
	jne	.L1254
.L1210:
	movl	$0, %ebx
	movl	$0, %r12d
	leaq	96(%rsp), %rbp
	jmp	.L1227
.L1253:
	leaq	64(%rsp), %rdi
	leaq	80(%rsp), %rax
	movq	%rax, 64(%rsp)
	movq	(%rsp), %rsi
	movq	%rsi, %rdx
	addq	8(%rsp), %rdx
.LEHB13:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE13:
	jmp	.L1255
.L1246:
	endbr64
	movq	%rax, %rbx
	movl	$1, %eax
.L1206:
	testb	%al, %al
	je	.L1232
	leaq	32(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1232:
	movq	%rsp, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	136(%rsp), %rax
	subq	%fs:40, %rax
	je	.L1235
	call	__stack_chk_fail@PLT
.L1255:
	movl	72(%rsp), %eax
	leal	-1(%rax), %ebx
	leaq	96(%rsp), %rdi
	leaq	112(%rsp), %rax
	movq	%rax, 96(%rsp)
	movq	(%rsp), %rsi
	movq	%rsi, %rdx
	addq	8(%rsp), %rdx
.LEHB14:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE14:
	jmp	.L1256
.L1242:
	endbr64
	movq	%rax, %rbx
	leaq	64(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movl	$1, %eax
	jmp	.L1206
.L1256:
	leaq	96(%rsp), %rdi
	movl	%ebx, %esi
	call	_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	cmpl	$43, %eax
	sete	%bl
	movq	96(%rsp), %rdi
	leaq	112(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1207
	movq	112(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1207:
	movq	64(%rsp), %rdi
	leaq	80(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1239
	movq	80(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L1239
.L1254:
	leaq	32(%rsp), %rdi
	leaq	48(%rsp), %rax
	movq	%rax, 32(%rsp)
	movq	(%rsp), %rsi
	movq	%rsi, %rdx
	addq	8(%rsp), %rdx
.LEHB15:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE15:
	movl	40(%rsp), %eax
	leal	-1(%rax), %ebx
	leaq	64(%rsp), %rdi
	leaq	80(%rsp), %rax
	movq	%rax, 64(%rsp)
	movq	(%rsp), %rsi
	movq	%rsi, %rdx
	addq	8(%rsp), %rdx
.LEHB16:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE16:
	leaq	96(%rsp), %rdi
	leaq	64(%rsp), %rsi
	movl	%ebx, %ecx
	movl	$0, %edx
.LEHB17:
	call	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
.LEHE17:
	movq	(%rsp), %rax
	leaq	16(%rsp), %rdx
	cmpq	%rdx, %rax
	je	.L1257
	movq	96(%rsp), %rdx
	leaq	112(%rsp), %rcx
	cmpq	%rcx, %rdx
	je	.L1258
	movq	16(%rsp), %rcx
	movq	%rdx, (%rsp)
	movq	104(%rsp), %rdx
	movq	%rdx, 8(%rsp)
	movq	112(%rsp), %rdx
	movq	%rdx, 16(%rsp)
	testq	%rax, %rax
	je	.L1222
	movq	%rax, 96(%rsp)
	movq	%rcx, 112(%rsp)
.L1221:
	movq	$0, 104(%rsp)
	movq	96(%rsp), %rax
	movb	$0, (%rax)
	movq	96(%rsp), %rdi
	leaq	112(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1223
	movq	112(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1223:
	movq	64(%rsp), %rdi
	leaq	80(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1224
	movq	80(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1224:
	movq	32(%rsp), %rdi
	leaq	48(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1210
	movq	48(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L1210
.L1257:
	movq	96(%rsp), %rdx
	leaq	112(%rsp), %rcx
	cmpq	%rcx, %rdx
	je	.L1259
	movq	%rdx, (%rsp)
	movq	104(%rsp), %rax
	movq	%rax, 8(%rsp)
	movq	112(%rsp), %rax
	movq	%rax, 16(%rsp)
.L1222:
	leaq	112(%rsp), %rax
	movq	%rax, 96(%rsp)
	jmp	.L1221
.L1259:
	movq	104(%rsp), %rcx
	jmp	.L1236
.L1265:
	cmpq	$1, %rcx
	je	.L1260
	leaq	112(%rsp), %rsi
	movl	%ecx, %edx
	cmpl	$8, %ecx
	jnb	.L1215
	testb	$4, %cl
	jne	.L1261
	testl	%ecx, %ecx
	je	.L1213
	movzbl	112(%rsp), %ecx
	movb	%cl, (%rax)
	testb	$2, %dl
	je	.L1213
	movl	%edx, %edx
	movzwl	-2(%rsi,%rdx), %ecx
	movw	%cx, -2(%rax,%rdx)
	jmp	.L1213
.L1260:
	movzbl	112(%rsp), %edx
	movb	%dl, (%rax)
	jmp	.L1213
.L1261:
	movl	112(%rsp), %ecx
	movl	%ecx, (%rax)
	movl	%edx, %edx
	movl	-4(%rsi,%rdx), %ecx
	movl	%ecx, -4(%rax,%rdx)
	jmp	.L1213
.L1215:
	movq	112(%rsp), %rdx
	movq	%rdx, (%rax)
	movl	%ecx, %edx
	movq	-8(%rsi,%rdx), %rdi
	movq	%rdi, -8(%rax,%rdx)
	leaq	8(%rax), %rdi
	andq	$-8, %rdi
	subq	%rdi, %rax
	movq	%rax, %rdx
	subq	%rax, %rsi
	addl	%ecx, %edx
	andl	$-8, %edx
	cmpl	$8, %edx
	jb	.L1213
	andl	$-8, %edx
	movl	$0, %eax
.L1219:
	movl	%eax, %ecx
	movq	(%rsi,%rcx), %r8
	movq	%r8, (%rdi,%rcx)
	addl	$8, %eax
	cmpl	%edx, %eax
	jb	.L1219
	jmp	.L1213
.L1263:
	movl	%ebx, %esi
	movq	%rbp, %rdi
	call	_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	addl	%eax, %r12d
	movq	96(%rsp), %rdi
	leaq	112(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1226
	movq	112(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1226:
	addl	$1, %ebx
.L1227:
	leaq	112(%rsp), %rax
	movq	%rax, 96(%rsp)
	movq	(%rsp), %rsi
	movq	%rsi, %rdx
	addq	8(%rsp), %rdx
	movq	%rbp, %rdi
.LEHB18:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
	movq	104(%rsp), %r13
	movq	96(%rsp), %rdi
	leaq	112(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1228
	movq	112(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1228:
	cmpl	%r13d, %ebx
	jge	.L1262
	leaq	112(%rsp), %rax
	movq	%rax, 96(%rsp)
	movq	(%rsp), %rsi
	movq	%rsi, %rdx
	addq	8(%rsp), %rdx
	movq	%rbp, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE18:
	jmp	.L1263
.L1262:
	movslq	%r12d, %rax
	imulq	$-1851608123, %rax, %rax
	shrq	$32, %rax
	addl	%r12d, %eax
	sarl	$9, %eax
	movl	%r12d, %edx
	sarl	$31, %edx
	subl	%edx, %eax
	imull	$900, %eax, %eax
	subl	%eax, %r12d
	addl	$100, %r12d
	movq	(%rsp), %rdi
	leaq	16(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1199
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1199:
	movq	136(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1264
	movl	%r12d, %eax
	addq	$152, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 40
	popq	%rbx
	.cfi_def_cfa_offset 32
	popq	%rbp
	.cfi_def_cfa_offset 24
	popq	%r12
	.cfi_def_cfa_offset 16
	popq	%r13
	.cfi_def_cfa_offset 8
	ret
.L1245:
	.cfi_restore_state
	endbr64
	movq	%rax, %rbx
	leaq	64(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1234:
	leaq	32(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	jmp	.L1232
.L1244:
	endbr64
	movq	%rax, %rbx
	jmp	.L1234
.L1243:
	endbr64
	movq	%rax, %rbx
	jmp	.L1232
.L1235:
	movq	%rbx, %rdi
.LEHB19:
	call	_Unwind_Resume@PLT
.LEHE19:
.L1258:
	movq	104(%rsp), %rcx
.L1236:
	testq	%rcx, %rcx
	jne	.L1265
.L1213:
	movq	104(%rsp), %rax
	movq	%rax, 8(%rsp)
	movq	(%rsp), %rdx
	movb	$0, (%rdx,%rax)
	jmp	.L1221
.L1247:
	endbr64
	movq	%rax, %rbx
	movl	$0, %eax
	jmp	.L1206
.L1264:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3826:
	.section	.gcc_except_table
.LLSDA3826:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3826-.LLSDACSB3826
.LLSDACSB3826:
	.uleb128 .LEHB11-.LFB3826
	.uleb128 .LEHE11-.LEHB11
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB12-.LFB3826
	.uleb128 .LEHE12-.LEHB12
	.uleb128 .L1247-.LFB3826
	.uleb128 0
	.uleb128 .LEHB13-.LFB3826
	.uleb128 .LEHE13-.LEHB13
	.uleb128 .L1246-.LFB3826
	.uleb128 0
	.uleb128 .LEHB14-.LFB3826
	.uleb128 .LEHE14-.LEHB14
	.uleb128 .L1242-.LFB3826
	.uleb128 0
	.uleb128 .LEHB15-.LFB3826
	.uleb128 .LEHE15-.LEHB15
	.uleb128 .L1243-.LFB3826
	.uleb128 0
	.uleb128 .LEHB16-.LFB3826
	.uleb128 .LEHE16-.LEHB16
	.uleb128 .L1244-.LFB3826
	.uleb128 0
	.uleb128 .LEHB17-.LFB3826
	.uleb128 .LEHE17-.LEHB17
	.uleb128 .L1245-.LFB3826
	.uleb128 0
	.uleb128 .LEHB18-.LFB3826
	.uleb128 .LEHE18-.LEHB18
	.uleb128 .L1243-.LFB3826
	.uleb128 0
	.uleb128 .LEHB19-.LFB3826
	.uleb128 .LEHE19-.LEHB19
	.uleb128 0
	.uleb128 0
.LLSDACSE3826:
	.text
	.size	_Z15GetSymbolCode30NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, .-_Z15GetSymbolCode30NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
	.globl	_Z21GenerateMagicNumber30v
	.type	_Z21GenerateMagicNumber30v, @function
_Z21GenerateMagicNumber30v:
.LFB3830:
	.cfi_startproc
	.cfi_personality 0x9b,DW.ref.__gxx_personality_v0
	.cfi_lsda 0x1b,.LLSDA3830
	endbr64
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	subq	$48, %rsp
	.cfi_def_cfa_offset 64
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	movq	%rsp, %rbx
	leaq	16(%rsp), %rax
	movq	%rax, (%rsp)
	movq	_ZL7_Symbol(%rip), %rsi
	movq	%rsi, %rdx
	addq	8+_ZL7_Symbol(%rip), %rdx
	movq	%rbx, %rdi
.LEHB20:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE20:
	movq	%rbx, %rdi
.LEHB21:
	call	_Z15GetSymbolCode30NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
.LEHE21:
	imull	$100000, %eax, %eax
	leal	1(%rax), %ebx
	movq	(%rsp), %rdi
	leaq	16(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1266
	movq	16(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1266:
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1273
	movl	%ebx, %eax
	addq	$48, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
.L1271:
	.cfi_restore_state
	endbr64
	movq	%rax, %rbx
	movq	%rsp, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	40(%rsp), %rax
	subq	%fs:40, %rax
	je	.L1269
	call	__stack_chk_fail@PLT
.L1269:
	movq	%rbx, %rdi
.LEHB22:
	call	_Unwind_Resume@PLT
.LEHE22:
.L1273:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3830:
	.section	.gcc_except_table
.LLSDA3830:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3830-.LLSDACSB3830
.LLSDACSB3830:
	.uleb128 .LEHB20-.LFB3830
	.uleb128 .LEHE20-.LEHB20
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB21-.LFB3830
	.uleb128 .LEHE21-.LEHB21
	.uleb128 .L1271-.LFB3830
	.uleb128 0
	.uleb128 .LEHB22-.LFB3830
	.uleb128 .LEHE22-.LEHB22
	.uleb128 0
	.uleb128 0
.LLSDACSE3830:
	.text
	.size	_Z21GenerateMagicNumber30v, .-_Z21GenerateMagicNumber30v
	.globl	_Z16StrategyInWindowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	.type	_Z16StrategyInWindowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi, @function
_Z16StrategyInWindowNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi:
.LFB3866:
	.cfi_startproc
	.cfi_personality 0x9b,DW.ref.__gxx_personality_v0
	.cfi_lsda 0x1b,.LLSDA3866
	endbr64
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$104, %rsp
	.cfi_def_cfa_offset 160
	movq	%rdi, %rbx
	movl	%esi, %r12d
	movq	%fs:40, %rax
	movq	%rax, 88(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %rdi
	leaq	32(%rsp), %rax
	movq	%rax, 16(%rsp)
	movq	(%rbx), %rsi
	movq	%rsi, %rdx
	addq	8(%rbx), %rdx
.LEHB23:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE23:
	movl	$1, %ebp
	cmpl	$11, 24(%rsp)
	je	.L1321
.L1275:
	movq	16(%rsp), %rdi
	leaq	32(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1280
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1280:
	testb	%bpl, %bpl
	je	.L1322
	movl	$0, %ebp
.L1274:
	movq	88(%rsp), %rax
	subq	%fs:40, %rax
	jne	.L1323
	movl	%ebp, %eax
	addq	$104, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L1321:
	.cfi_restore_state
	leaq	48(%rsp), %rdi
	leaq	64(%rsp), %rax
	movq	%rax, 48(%rsp)
	movq	(%rbx), %rsi
	movq	%rsi, %rdx
	addq	8(%rbx), %rdx
.LEHB24:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE24:
	jmp	.L1324
.L1309:
	endbr64
	movq	%rax, %rbx
	leaq	16(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1278:
	movq	88(%rsp), %rax
	subq	%fs:40, %rax
	je	.L1292
	call	__stack_chk_fail@PLT
.L1324:
	leaq	48(%rsp), %rdi
	movl	$5, %esi
	call	_Z18StringGetCharacterNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi
	cmpl	$45, %eax
	setne	%bpl
	movq	48(%rsp), %rdi
	leaq	64(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1275
	movq	64(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
	jmp	.L1275
.L1322:
	leaq	16(%rsp), %r13
	leaq	32(%rsp), %rax
	movq	%rax, 16(%rsp)
	movq	(%rbx), %rsi
	movq	%rsi, %rdx
	addq	8(%rbx), %rdx
	movq	%r13, %rdi
.LEHB25:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE25:
	leaq	48(%rsp), %rdi
	movl	$2, %ecx
	movl	$0, %edx
	movq	%r13, %rsi
.LEHB26:
	call	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
.LEHE26:
	leaq	48(%rsp), %rdi
.LEHB27:
	call	_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
.LEHE27:
	movq	%rax, %r14
	movq	48(%rsp), %rdi
	leaq	64(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1282
	movq	64(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1282:
	movq	16(%rsp), %rdi
	leaq	32(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1283
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1283:
	leaq	16(%rsp), %r13
	leaq	32(%rsp), %rax
	movq	%rax, 16(%rsp)
	movq	(%rbx), %rsi
	movq	%rsi, %rdx
	addq	8(%rbx), %rdx
	movq	%r13, %rdi
.LEHB28:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE28:
	leaq	48(%rsp), %rdi
	movl	$2, %ecx
	movl	$3, %edx
	movq	%r13, %rsi
.LEHB29:
	call	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
.LEHE29:
	leaq	48(%rsp), %rdi
.LEHB30:
	call	_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
.LEHE30:
	movq	%rax, 8(%rsp)
	movq	48(%rsp), %rdi
	leaq	64(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1284
	movq	64(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1284:
	movq	16(%rsp), %rdi
	leaq	32(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1285
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1285:
	leaq	16(%rsp), %r13
	leaq	32(%rsp), %rax
	movq	%rax, 16(%rsp)
	movq	(%rbx), %rsi
	movq	%rsi, %rdx
	addq	8(%rbx), %rdx
	movq	%r13, %rdi
.LEHB31:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE31:
	leaq	48(%rsp), %rdi
	movl	$2, %ecx
	movl	$6, %edx
	movq	%r13, %rsi
.LEHB32:
	call	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
.LEHE32:
	leaq	48(%rsp), %rdi
.LEHB33:
	call	_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
.LEHE33:
	movq	%rax, %r13
	movq	48(%rsp), %rdi
	leaq	64(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1286
	movq	64(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1286:
	movq	16(%rsp), %rdi
	leaq	32(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1287
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1287:
	leaq	16(%rsp), %r15
	leaq	32(%rsp), %rax
	movq	%rax, 16(%rsp)
	movq	(%rbx), %rsi
	movq	%rsi, %rdx
	addq	8(%rbx), %rdx
	movq	%r15, %rdi
.LEHB34:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
.LEHE34:
	leaq	48(%rsp), %rdi
	movl	$2, %ecx
	movl	$9, %edx
	movq	%r15, %rsi
.LEHB35:
	call	_Z12StringSubstrNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEii
.LEHE35:
	leaq	48(%rsp), %rdi
.LEHB36:
	call	_Z15StringToIntegerNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE
.LEHE36:
	movq	%rax, %rbx
	movq	48(%rsp), %rdi
	leaq	64(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1288
	movq	64(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1288:
	movq	16(%rsp), %rdi
	leaq	32(%rsp), %rax
	cmpq	%rax, %rdi
	je	.L1289
	movq	32(%rsp), %rax
	leaq	1(%rax), %rsi
	call	_ZdlPvm@PLT
.L1289:
	cmpl	$23, %r14d
	setg	%al
	cmpl	$23, %r13d
	setg	%dl
	orb	%dl, %al
	jne	.L1274
	movq	8(%rsp), %rcx
	cmpl	$59, %ecx
	jg	.L1308
	cmpl	$59, %ebx
	jg	.L1308
	imull	$60, %r14d, %r14d
	addl	%ecx, %r14d
	imull	$60, %r13d, %r13d
	addl	%ebx, %r13d
	cmpl	%r13d, %r14d
	jle	.L1290
	cmpl	%r12d, %r14d
	setle	%bpl
	cmpl	%r12d, %r13d
	setg	%al
	orl	%eax, %ebp
	jmp	.L1274
.L1290:
	cmpl	%r12d, %r14d
	setle	%bpl
	cmpl	%r12d, %r13d
	setg	%al
	andl	%eax, %ebp
	jmp	.L1274
.L1308:
	movl	%eax, %ebp
	jmp	.L1274
.L1318:
	endbr64
	movq	%rax, %rbx
	jmp	.L1278
.L1292:
	movq	%rbx, %rdi
.LEHB37:
	call	_Unwind_Resume@PLT
.L1311:
	endbr64
	movq	%rax, %rbx
	leaq	48(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1294:
	leaq	16(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	88(%rsp), %rax
	subq	%fs:40, %rax
	je	.L1295
	call	__stack_chk_fail@PLT
.L1310:
	endbr64
	movq	%rax, %rbx
	jmp	.L1294
.L1295:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.L1313:
	endbr64
	movq	%rax, %rbx
	leaq	48(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1297:
	leaq	16(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	88(%rsp), %rax
	subq	%fs:40, %rax
	je	.L1298
	call	__stack_chk_fail@PLT
.L1312:
	endbr64
	movq	%rax, %rbx
	jmp	.L1297
.L1298:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.L1315:
	endbr64
	movq	%rax, %rbx
	leaq	48(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1300:
	leaq	16(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	88(%rsp), %rax
	subq	%fs:40, %rax
	je	.L1301
	call	__stack_chk_fail@PLT
.L1314:
	endbr64
	movq	%rax, %rbx
	jmp	.L1300
.L1301:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.L1317:
	endbr64
	movq	%rax, %rbx
	leaq	48(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
.L1303:
	leaq	16(%rsp), %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	88(%rsp), %rax
	subq	%fs:40, %rax
	je	.L1304
	call	__stack_chk_fail@PLT
.L1316:
	endbr64
	movq	%rax, %rbx
	jmp	.L1303
.L1304:
	movq	%rbx, %rdi
	call	_Unwind_Resume@PLT
.LEHE37:
.L1323:
	call	__stack_chk_fail@PLT
	.cfi_endproc
.LFE3866:
	.section	.gcc_except_table
.LLSDA3866:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3866-.LLSDACSB3866
.LLSDACSB3866:
	.uleb128 .LEHB23-.LFB3866
	.uleb128 .LEHE23-.LEHB23
	.uleb128 .L1318-.LFB3866
	.uleb128 0
	.uleb128 .LEHB24-.LFB3866
	.uleb128 .LEHE24-.LEHB24
	.uleb128 .L1309-.LFB3866
	.uleb128 0
	.uleb128 .LEHB25-.LFB3866
	.uleb128 .LEHE25-.LEHB25
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB26-.LFB3866
	.uleb128 .LEHE26-.LEHB26
	.uleb128 .L1310-.LFB3866
	.uleb128 0
	.uleb128 .LEHB27-.LFB3866
	.uleb128 .LEHE27-.LEHB27
	.uleb128 .L1311-.LFB3866
	.uleb128 0
	.uleb128 .LEHB28-.LFB3866
	.uleb128 .LEHE28-.LEHB28
	.uleb128 0
	.