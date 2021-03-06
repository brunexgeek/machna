//
// sched.s
//
// Task scheduler "naked" functions for x86
//
// Copyright (C) 2013-2014 Bruno Ribeiro. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Neither the name of the project nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//


#include <os/syspage.h>
#include <os/pdir.h>
#include <os/sched.h>


    .intel_syntax noprefix
    .text
    .global ___switch_context
    .global ___kthread_self


___switch_context:
    // save registers on current kernel stack
    push    ebp
    push    ebx
    push    edi
    push    esi

    // store kernel stack pointer in tcb
    mov     eax, esp
    and     eax, TCBMASK
    add     eax, TCBESP
    mov     [eax], esp

    // get stack pointer for new thread and store in esp0
    mov     eax, 20[esp]
    add     eax, TCBESP
    mov     esp, [eax]
    mov     ebp, TSS_ESP0
    mov     [ebp], eax

    // restore registers from new kernel stack
    pop     esi
    pop     edi
    pop     ebx
    pop     ebp

    ret
    nop


___kthread_self:
    mov eax, esp
    and eax, TCBMASK
    ret
