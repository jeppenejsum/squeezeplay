/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"


static const char *JIVE_FONT_MAGIC = "Font";

static JiveFont *fonts = NULL;


static int load_ttf_font(JiveFont *font, const char *name, Uint16 size);

static void destroy_ttf_font(JiveFont *font);

static int width_ttf_font(JiveFont *font, const char *str);

static SDL_Surface *draw_ttf_font(JiveFont *font, Uint32 color, const char *str);



JiveFont *jive_font_load(const char *name, Uint16 size) {

	// Do we already have this font loaded?
	JiveFont *ptr = fonts;
	while (ptr) {
		if (ptr->size == size &&
		    strcmp(ptr->name, name) == 0) {
			ptr->refcount++;
			return ptr;
		}

		ptr = ptr->next;
	}

	/* Initialise the TTF api when required */
	if (!TTF_WasInit() && TTF_Init() == -1) {
		LOG_WARN(log_ui_draw, "TTF_Init: %s\n", TTF_GetError());
		exit(-1);
	}

	ptr = calloc(sizeof(JiveFont), 1);
	
	if (!load_ttf_font(ptr, name, size)) {
		free(ptr);
		return NULL;
	}

	ptr->refcount = 1;
	ptr->name = strdup(name);
	ptr->size = size;
	ptr->next = fonts;
	ptr->magic = JIVE_FONT_MAGIC;
	fonts = ptr;

	return ptr;
}

JiveFont *jive_font_ref(JiveFont *font) {
	if (font) {
		assert(font->magic == JIVE_FONT_MAGIC);
		++font->refcount;
	}
	return font;
}

void jive_font_free(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	if (--font->refcount > 0) {
		return;
	}

	if (font == fonts) {
		fonts = font->next;
	}
	else {
		JiveFont *ptr = fonts;
		while (ptr) {
			if (ptr->next == font) {
				ptr->next = font->next;
				break;
			}

			ptr = ptr->next;
		}
	}

	font->destroy(font);
	free(font->name);
	free(font);

	/* Shutdown the TTF api when all fonts are free */
	if (fonts == NULL && TTF_WasInit()) {
		TTF_Quit();
	}
}

int jive_font_width(JiveFont *font, const char *str) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->width(font, str);
}

int jive_font_nwidth(JiveFont *font, const char *str, size_t len) {
	int w;
	char *tmp;

	assert(font && font->magic == JIVE_FONT_MAGIC);

	if (len <= 0) {
		return 0;
	}

	// FIXME use utf8 len
	tmp = malloc(len + 1);
	strncpy(tmp, str, len);
	*(tmp + len) = '\0';
	
	w = font->width(font, tmp);

	free(tmp);

	return w;
}

int jive_font_capheight(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->capheight;
}

int jive_font_height(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->height;
}

int jive_font_ascend(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->ascend;
}

int jive_font_offset(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->ascend - font->capheight;
}

static int load_ttf_font(JiveFont *font, const char *name, Uint16 size) {
	int miny, maxy, descent;
	char *fullpath = malloc(PATH_MAX);

	if (!squeezeplay_find_file(name, fullpath) ) {
		free(fullpath);
		LOG_WARN(log_ui_draw, "Cannot find font %s\n", name);
		return 0;
	}

	font->ttf = TTF_OpenFont(fullpath, size);
	if (!font->ttf) {
		free(fullpath);
		LOG_WARN(log_ui_draw, "TTF_OpenFont: %s\n", TTF_GetError());
		return 0;
	}
	free(fullpath);

	font->ascend = TTF_FontAscent(font->ttf);

	/* calcualte the cap height using H */
	if (TTF_GlyphMetrics(font->ttf, 'H', NULL, NULL, NULL, &maxy, NULL) == 0) {
		font->capheight = maxy;
	}
	else {
		font->capheight = font->ascend;
	}

	/* calcualte the non diacritical descent using g */
	if (TTF_GlyphMetrics(font->ttf, 'g', NULL, NULL, &miny, NULL, NULL) == 0) {
		descent = miny;
	}
	else {
		descent = TTF_FontDescent(font->ttf);
	}

	/* calculate the font height, using the capheight and descent */
	font->height = font->capheight - descent + 1;

	font->width = width_ttf_font;
	font->draw = draw_ttf_font;
	font->destroy = destroy_ttf_font;

	return 1;
}

static void destroy_ttf_font(JiveFont *font) {
	if (font->ttf) {
		TTF_CloseFont(font->ttf);
		font->ttf = NULL;
	}
}

static int width_ttf_font(JiveFont *font, const char *str) {
	int w, h;

	if (!str) {
		return 0;
	}

	TTF_SizeUTF8(font->ttf, str, &w, &h);
	return w;
}

static SDL_Surface *draw_ttf_font(JiveFont *font, Uint32 color, const char *str) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = SDL_GetTicks(), t1;
#endif //JIVE_PROFILE_BLIT
	SDL_Color clr;
	SDL_Surface *srf;

	clr.r = (color >> 24) & 0xFF;
	clr.g = (color >> 16) & 0xFF;
	clr.b = (color >> 8) & 0xFF;

	srf = TTF_RenderUTF8_Blended(font->ttf, str, clr);

#if 0
	// draw text bounding box for debugging
	if (srf) {
		rectangleColor(srf, 0,0, srf->w - 1, srf->h - 1, 0xff0000df);
		lineColor(srf, 0, font->ascend, srf->w - 1, font->ascend, 0xff0000df);
		lineColor(srf, 0, font->ascend, srf->w - 1, font->ascend, 0xff0000df);
		lineColor(srf, 0, font->ascend - font->capheight, srf->w - 1, font->ascend - font->capheight, 0xff0000df);
	}
#endif


#ifdef JIVE_PROFILE_BLIT
	t1 = SDL_GetTicks();
	printf("\tdraw_ttf_font took=%d %s\n", t1-t0, str);
#endif //JIVE_PROFILE_BLIT

	return srf;
}

JiveSurface *jive_font_draw_text(JiveFont *font, Uint32 color, const char *str) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return jive_surface_new_SDLSurface(str ? font->draw(font, color, str) : NULL);
}

JiveSurface *jive_font_ndraw_text(JiveFont *font, Uint32 color, const char *str, size_t len) {
	JiveSurface *srf;
	char *tmp;

	// FIXME use utf8 len

	tmp = malloc(len + 1);
	strncpy(tmp, str, len);
	*(tmp + len) = '\0';
	
	srf = jive_font_draw_text(font, color, tmp);

	free(tmp);

	return srf;
}
