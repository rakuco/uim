/*
  Copyright (c) 2005-2006 uim Project http://uim.freedesktop.org/

  All rights reserved.

  Redistribution and use in source and binary forms, with or
  without modification, are permitted provided that the
  following conditions are met:

  1. Redistributions of source code must retain the above
     copyright notice, this list of conditions and the
     following disclaimer.
  2. Redistributions in binary form must reproduce the above
     copyright notice, this list of conditions and the
     following disclaimer in the documentation and/or other
     materials provided with the distribution.
  3. Neither the name of authors nor the names of its
     contributors may be used to endorse or promote products
     derived from this software without specific prior written
     permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
  CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef _uim_agent_context_h_included_
#define _uim_agent_context_h_included_

#include <string.h>
#include <stdlib.h>
#include <locale.h>

#include <uim/uim.h>
#include <uim/uim-im-switcher.h>

#include "debug.h"
#include "prop.h"
#include "preedit.h"
#include "im.h"
#include "callback.h"
#include "encoding.h"

typedef struct uim_agent_context {
  uim_context context;
  int context_id;
  char *encoding;
  char *im;
  preedit *pe;
  property *prop;
} uim_agent_context;


typedef struct uim_agent_context_list {
  uim_agent_context *agent_context;
  struct uim_agent_context_list *next;
  struct uim_agent_context_list *prev;
} uim_agent_context_list;


uim_context create_context(const char *encoding, uim_agent_context *ptr);

uim_agent_context *create_uim_agent_context(const char *encoding);
uim_agent_context *new_uim_agent_context(int id, const char *encoding);
int release_uim_agent_context(int id);

uim_agent_context *get_uim_agent_context(int id);

uim_agent_context *switch_context_im(uim_agent_context *ua, const char *im,
									 const char *encoding);

void update_context_configuration(uim_agent_context *ua);

/* current focused context */
extern uim_agent_context *current;

extern uim_agent_context_list *agent_context_list_head;
extern uim_agent_context_list *agent_context_list_tail;


#endif
