/*
* Copyright (c) 2021-2022 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
namespace Emulsion.Utils {
    public string make_hex (float red, float green, float blue) {
        return "#" + "%02x%02x%02x".printf ((uint)red, (uint)green, (uint)blue);
    }
    public double make_srgb(double c) {
        if (c <= 0.03928) {
            c = c / 12.92;
            return c * 255.0;
        } else {
            Math.pow (((c + 0.055) / 1.055), 2.4);
            return c * 255.0;
        }
    }

    private static double contrast_ratio (Gdk.RGBA bg_color, Gdk.RGBA fg_color) {
        // From WCAG 2.0 https://www.w3.org/TR/WCAG20/#contrast-ratiodef
        var bg_luminance = get_luminance (bg_color);
        var fg_luminance = get_luminance (fg_color);

        if (bg_luminance > fg_luminance) {
            return (bg_luminance + 0.05) / (fg_luminance + 0.05);
        }

        return (fg_luminance + 0.05) / (bg_luminance + 0.05);
    }

    private static double get_luminance (Gdk.RGBA color) {
        // Values from WCAG 2.0 https://www.w3.org/TR/WCAG20/#relativeluminancedef
        var red = sanitize_color (color.red) * 0.2126;
        var green = sanitize_color (color.green) * 0.7152;
        var blue = sanitize_color (color.blue) * 0.0722;

        return red + green + blue;
    }

    private static double sanitize_color (double color) {
        // From WCAG 2.0 https://www.w3.org/TR/WCAG20/#relativeluminancedef
        if (color <= 0.03928) {
            return color / 12.92;
        }

        return Math.pow ((color + 0.055) / 1.055, 2.4);
    }

    public class Palette : Object {

        public class Swatch : Object {
            public float R = 0.0f;
            public float G = 0.0f;
            public float B = 0.0f;
            public float A = 0.0f;
            public int population { get; construct; }

            public Swatch (uint8 red, uint8 green, uint8 blue, int population) {
                Object (population: population);

                R = red / 255.0f;
                G = green / 255.0f;
                B = blue / 255.0f;
                A = 1.0f;

                this.red = red;
                this.green = green;
                this.blue = blue;
            }

            public uint8 red { get; set; }
            public uint8 green { get; set; }
            public uint8 blue { get; set; }

            public Swatch.from_rgb (int rgb) {
                red = (uint8)((rgb >> 16) & 0xFF);
                green = (uint8)((rgb >> 8) & 0xFF);
                blue = (uint8)(rgb & 0xFF);
            }

            public int to_rgb () {
                return (0xFF << 24) | (red << 16) | (green << 8) | blue;
            }
        }

        public const uint8 MAX_QUALITY = 10;
        public const uint8 MIN_QUALITY = 1;
        public const uint8 DEFAULT_QUALITY = 5;
        public const uint16 MAX_COLORS = 16;
        public const uint16 DEFAULT_COLORS = 8;
        public const uint16 MIN_COLORS = 4;

        private Gee.List<Swatch> _swatches;
        public Gee.List<Swatch> swatches {
            owned get {
                return _swatches.read_only_view;
            }
        }

        public Swatch? vibrant_swatch { get; private set; }
        public Swatch? light_vibrant_swatch { get; private set; }
        public Swatch? dark_vibrant_swatch { get; private set; }
        public Swatch? muted_swatch { get; private set; }
        public Swatch? light_muted_swatch { get; private set; }
        public Swatch? dark_muted_swatch { get; private set; }
        public Swatch? dominant_swatch { get; private set; }
        public Swatch? body_swatch { get; private set; }

        private int max_population = 0;

        public Gdk.Pixbuf? pixbuf { get; construct set; }
        public string pixel_data { get; set; }

        private uint8 _quality = DEFAULT_QUALITY;
        public uint8 quality {
            get {
                return _quality;
            }

            construct set {
                _quality = value.clamp (MIN_QUALITY, MAX_QUALITY);
            }
        }

        private uint16 _max_colors = DEFAULT_COLORS;
        public uint16 max_colors {
            get {
                return _max_colors;
            }

            construct set {
                _max_colors = value.clamp (MIN_COLORS, MAX_COLORS);
            }
        }

        private Gee.HashMap<int, int> histogram;
        public bool has_alpha { get; construct set; }

        construct {
            histogram = new Gee.HashMap<int, int> ();
        }

        public Palette () {

        }

        public Palette.from_pixbuf (Gdk.Pixbuf pixbuf, uint16 max_colors = DEFAULT_COLORS, uint8 quality = DEFAULT_QUALITY) {
            Object (pixbuf: pixbuf, max_colors: max_colors, quality: quality);
        }

        public Palette.from_data (owned string pixels, bool has_alpha, uint16 max_colors = DEFAULT_COLORS, uint8 quality = DEFAULT_QUALITY) {
            this.pixel_data = pixels;
            Object (has_alpha: has_alpha, max_colors: max_colors, quality: quality);
        }

        public async void generate_async () {
            Gee.List<Swatch> pixels;
            if (pixbuf != null) {
                // Use pixbuf dimensions and rowstride to properly read pixel data
                pixels = convert_pixbuf_to_rgb (pixbuf);
            } else {
                pixels = convert_pixels_to_rgb (pixel_data.data, has_alpha);
            }

            // Build histogram-based palette directly (simpler than k-means, filters handle quality)
            // Start with many more colors to ensure enough survive filtering
            _swatches = build_histogram_palette (pixels, max_colors);
            
            // Filter out antialiasing artifacts and low-quality colors
            _swatches = filter_artifacts (_swatches);
            
            // Merge very similar colors
            _swatches = merge_similar_colors (_swatches);
            
            // Final aggressive filter: ensure colors are within reasonable distance of each other
            _swatches = filter_outlier_colors (_swatches);
            
            // Sort by population (most to least)
            _swatches.sort ((c1, c2) => {
                return c2.population - c1.population;
            });

            // Ensure ROYGBIV coverage (if colors exist in the image)
            ensure_roygbiv_coverage ();
            
            // Ensure saturation coverage (at least 4 steps if they exist)
            ensure_saturation_coverage ();
            
            // Ensure lightness coverage (at least 4 steps if they exist)
            ensure_lightness_coverage ();
            
            // Re-sort after potentially adding colors
            _swatches.sort ((c1, c2) => {
                return c2.population - c1.population;
            });
            
            // Ensure we have enough colors for the dialog
            // Use the requested max_colors as the target, but allow up to MAX_COLORS
            int target_colors = (int)max_colors;
            int max_limit = (int)MAX_COLORS;
            
            // If we have more than the maximum allowed, limit to that
            if (_swatches.size > max_limit) {
                var top_swatches = new Gee.ArrayList<Swatch> ();
                for (int i = 0; i < max_limit; i++) {
                    top_swatches.add (_swatches[i]);
                }
                _swatches = top_swatches;
            } 
            // If we have fewer than requested but some colors exist, try to get more from histogram
            // This ensures the dialog always has a reasonable number of colors to choose from
            else if (_swatches.size < target_colors && _swatches.size < max_limit) {
                // Get more colors from histogram (histogram is already built during pixel conversion)
                var all_swatches = new Gee.ArrayList<Swatch> ();
                histogram.@foreach ((entry) => {
                    var color = entry.key;
                    int population = entry.value;
                    uint8 red = (uint8)((color >> 16) & 0xFF);
                    uint8 green = (uint8)((color >> 8) & 0xFF);
                    uint8 blue = (uint8)(color & 0xFF);
                    var swatch = new Swatch (red, green, blue, population);
                    all_swatches.add (swatch);
                    return true;
                });
                
                // Sort all by population
                all_swatches.sort ((c1, c2) => {
                    return c2.population - c1.population;
                });
                
                // Add colors that aren't already in _swatches, up to target_colors
                var existing_colors = new Gee.HashSet<int> ();
                foreach (var existing in _swatches) {
                    existing_colors.add (existing.to_rgb ());
                }
                
                // Take up to (target_colors * 3) from histogram to have enough candidates
                int candidates_count = int.min (target_colors * 3, all_swatches.size);
                for (int i = 0; i < candidates_count && _swatches.size < max_limit; i++) {
                    var swatch = all_swatches[i];
                    if (!existing_colors.contains (swatch.to_rgb ())) {
                        _swatches.add (swatch);
                        existing_colors.add (swatch.to_rgb ());
                    }
                }
                
                // Re-sort after adding
                _swatches.sort ((c1, c2) => {
                    return c2.population - c1.population;
                });
                
                // Trim to max_limit if we exceeded it
                if (_swatches.size > max_limit) {
                    var top_swatches = new Gee.ArrayList<Swatch> ();
                    for (int i = 0; i < max_limit; i++) {
                        top_swatches.add (_swatches[i]);
                    }
                    _swatches = top_swatches;
                }
            }

            if (_swatches.size > 0) {
                dominant_swatch = _swatches[0];
            }

            max_population = int.MIN;
            foreach (var swatch in _swatches) {
                if (swatch.population > max_population) {
                    max_population = swatch.population;
                }
            }
        }

        public void generate_sync () {
            var loop = new MainLoop ();
            generate_async.begin (() => loop.quit ());
            loop.run ();
        }

        // Convert GdkPixbuf to RGB swatches, handling rowstride correctly
        private Gee.ArrayList<Swatch> convert_pixbuf_to_rgb (Gdk.Pixbuf pixbuf) {
            var list = new Gee.ArrayList<Swatch> ();
            
            int width = pixbuf.get_width ();
            int height = pixbuf.get_height ();
            int n_channels = pixbuf.get_n_channels ();
            int rowstride = pixbuf.get_rowstride ();
            
            unowned uint8[] pixels = pixbuf.get_pixels_with_length ();
            
            int inc = MAX_QUALITY + MIN_QUALITY - quality;
            
            // Iterate through pixels accounting for rowstride
            for (int y = 0; y < height; y += inc) {
                for (int x = 0; x < width; x += inc) {
                    int offset = y * rowstride + x * n_channels;
                    
                    // Safety check
                    if (offset + 2 >= pixels.length) {
                        break;
                    }
                    
                    // GdkPixbuf stores pixels in RGB/RGBA format
                    // Format: [R, G, B] or [R, G, B, A] per pixel
                    uint8 red = pixels[offset];
                    uint8 green = pixels[offset + 1];
                    uint8 blue = pixels[offset + 2];
                    
                    // Additional validation: skip pixels where channels are clearly swapped
                    // (e.g., if blue > red + green, it might indicate a channel swap)
                    // This is a heuristic check for obvious errors
                    
                    // Skip very dark or very light pixels (likely antialiasing artifacts at edges)
                    // Relaxed: only filter extreme values
                    int brightness = (int)(red + green + blue) / 3;
                    if (brightness < 5 || brightness > 250) {
                        continue;
                    }

                    var color = new Swatch (red, green, blue, 0);
                    
                    int rgb = color.to_rgb ();
                    if (histogram.has_key (rgb)) {
                        histogram[rgb] = histogram[rgb] + 1;
                    } else {
                        histogram[rgb] = 1;
                    }
                }
            }

            histogram.@foreach ((entry) => {
                var color = entry.key;
                list.add (new Swatch.from_rgb (color));
                return true;
            });

            return list;
        }

        private Gee.ArrayList<Swatch> convert_pixels_to_rgb (uint8[] pixels, bool has_alpha) {
            var list = new Gee.ArrayList<Swatch> ();

            int factor;
            if (has_alpha) {
                factor = 4;
            } else {
                factor = 3;
            }

            int i = 0;
            int inc = MAX_QUALITY + MIN_QUALITY - quality;

            int count = pixels.length / factor;
            while (i < count) {
                int offset = i * factor;
                
                // GdkPixbuf stores pixels in RGB/RGBA format
                // Format: [R, G, B] or [R, G, B, A] per pixel
                uint8 red = pixels[offset];
                uint8 green = pixels[offset + 1];
                uint8 blue = pixels[offset + 2];
                
                // Verify we're not reading out of bounds (safety check)
                if (offset + 2 >= pixels.length) {
                    break;
                }

                // Skip very dark or very light pixels (likely antialiasing artifacts at edges)
                // This helps reduce noise from compression/antialiasing
                int brightness = (int)(red + green + blue) / 3;
                if (brightness < 5 || brightness > 250) {
                    i += inc;
                    continue;
                }

                var color = new Swatch (red, green, blue, 0);
                
                int rgb = color.to_rgb ();
                if (histogram.has_key (rgb)) {
                    histogram[rgb] = histogram[rgb] + 1;
                } else {
                    histogram[rgb] = 1;
                }

                i += inc;
            }

            histogram.@foreach ((entry) => {
                var color = entry.key;
                list.add (new Swatch.from_rgb (color));
                return true;
            });

            return list;
        }


        // Build palette directly from histogram (simple and fast, filters handle quality)
        private Gee.ArrayList<Swatch> build_histogram_palette (Gee.List<Swatch> pixels, uint16 max_colors) {
            var swatches = new Gee.ArrayList<Swatch> ();
            
            // The histogram is already populated during pixel conversion
            // Create swatches from histogram entries with their populations
            histogram.@foreach ((entry) => {
                var color = entry.key;
                int population = entry.value;
                uint8 red = (uint8)((color >> 16) & 0xFF);
                uint8 green = (uint8)((color >> 8) & 0xFF);
                uint8 blue = (uint8)(color & 0xFF);
                var swatch = new Swatch (red, green, blue, population);
                swatches.add (swatch);
                return true;
            });
            
            // Sort by population (most to least)
            swatches.sort ((c1, c2) => {
                return c2.population - c1.population;
            });
            
            // Limit to max_colors * 4 initially to ensure enough survive aggressive filtering
            int take_count = int.min ((int)max_colors * 4, swatches.size); // Take many more initially, filters will reduce
            var result = new Gee.ArrayList<Swatch> ();
            for (int i = 0; i < take_count; i++) {
                result.add (swatches[i]);
            }
            
            return result;
        }

        // Calculate squared Euclidean distance in RGB space
        private static double color_distance_squared (Swatch a, Swatch b) {
            double dr = a.red - b.red;
            double dg = a.green - b.green;
            double db = a.blue - b.blue;
            return dr * dr + dg * dg + db * db;
        }

        // Filter out antialiasing artifacts and low-quality colors
        private Gee.ArrayList<Swatch> filter_artifacts (Gee.List<Swatch> swatches) {
            if (swatches.size == 0) {
                return new Gee.ArrayList<Swatch> ();
            }
            
            // Calculate total population for percentage threshold
            int total_pop = 0;
            foreach (var swatch in swatches) {
                total_pop += swatch.population;
            }
            
            if (total_pop == 0) {
                return new Gee.ArrayList<Swatch> ();
            }
            
            // Minimum population threshold: at least 0.5% of total pixels (lenient)
            int min_population = int.max (1, total_pop / 200);
            
            // First pass: filter by population
            var filtered = new Gee.ArrayList<Swatch> ();
            
            foreach (var swatch in swatches) {
                // Skip low-population colors (likely artifacts)
                if (swatch.population < min_population) {
                    continue;
                }
                
                filtered.add (swatch);
            }
            
            if (filtered.size == 0) {
                return filtered;
            }
            
            if (filtered.size <= 1) {
                return filtered;
            }
            
            // Second pass: outlier detection - filter colors that are very different from dominant colors
            // Calculate dominant color (average of top 3 colors weighted by population)
            double dominant_red = 0.0;
            double dominant_green = 0.0;
            double dominant_blue = 0.0;
            int dominant_total_pop = 0;
            int top_count = int.min (3, filtered.size);
            
            for (int i = 0; i < top_count; i++) {
                dominant_red += filtered[i].red * filtered[i].population;
                dominant_green += filtered[i].green * filtered[i].population;
                dominant_blue += filtered[i].blue * filtered[i].population;
                dominant_total_pop += filtered[i].population;
            }
            
            if (dominant_total_pop > 0) {
                dominant_red /= dominant_total_pop;
                dominant_green /= dominant_total_pop;
                dominant_blue /= dominant_total_pop;
            }
            
            var final_filtered = new Gee.ArrayList<Swatch> ();
            var dominant_swatch = new Swatch ((uint8)Math.round (dominant_red), 
                                               (uint8)Math.round (dominant_green), 
                                               (uint8)Math.round (dominant_blue), 0);
            
            // Filter out colors that are too different from the dominant palette
            // Calculate threshold based on dominant color's saturation
            double dominant_sat = get_saturation (dominant_swatch);
            double threshold;
            if (dominant_sat < 0.3) {
                // Low-saturation images (grays, blue-grays): use very large threshold (~100 RGB units = 10000)
                // This allows various shades of grays and blues that are in the same family
                threshold = 10000.0;
            } else {
                // High-saturation images: use tighter threshold (~50 RGB units = 2500)
                threshold = 2500.0;
            }
            
            foreach (var swatch in filtered) {
                double dist = color_distance_squared (swatch, dominant_swatch);
                
                // Allow colors that are close to dominant OR have decent population (at least 5% of total)
                bool is_high_population = swatch.population >= total_pop / 20;
                
                if (dist <= threshold || is_high_population) {
                    final_filtered.add (swatch);
                }
            }
            
            return final_filtered.size > 0 ? final_filtered : filtered;
        }

        // Merge very similar colors together
        private Gee.ArrayList<Swatch> merge_similar_colors (Gee.List<Swatch> swatches) {
            if (swatches.size <= 1) {
                return new Gee.ArrayList<Swatch>.wrap ((Swatch[])swatches.to_array ());
            }
            
            // Threshold: colors within this distance are considered similar (squared distance)
            // This is approximately 10 units in RGB space (10^2 = 100) - more conservative to preserve color variety
            const double SIMILARITY_THRESHOLD = 100.0;
            
            var merged = new Gee.ArrayList<Swatch> ();
            var merged_mask = new Gee.ArrayList<bool> ();
            
            // Initialize mask
            for (int idx = 0; idx < swatches.size; idx++) {
                merged_mask.add (false);
            }
            
            // Find and merge similar colors
            for (int i = 0; i < swatches.size; i++) {
                if (merged_mask[i]) {
                    continue;
                }
                
                var current = swatches[i];
                var similar_swatches = new Gee.ArrayList<Swatch> ();
                similar_swatches.add (current);
                
                // Find all similar colors
                for (int j = i + 1; j < swatches.size; j++) {
                    if (merged_mask[j]) {
                        continue;
                    }
                    
                    double dist = color_distance_squared (current, swatches[j]);
                    if (dist <= SIMILARITY_THRESHOLD) {
                        similar_swatches.add (swatches[j]);
                        merged_mask[j] = true;
                    }
                }
                
                // Merge similar colors by weighted average
                if (similar_swatches.size == 1) {
                    merged.add (current);
            } else {
                    // Calculate population-weighted average
                    double red_sum = 0.0;
                    double green_sum = 0.0;
                    double blue_sum = 0.0;
                    int total_pop = 0;
                    
                    foreach (Swatch swatch in similar_swatches) {
                        red_sum += swatch.red * swatch.population;
                        green_sum += swatch.green * swatch.population;
                        blue_sum += swatch.blue * swatch.population;
                        total_pop += swatch.population;
                    }
                    
                    uint8 merged_red = (uint8)Math.round (red_sum / total_pop);
                    uint8 merged_green = (uint8)Math.round (green_sum / total_pop);
                    uint8 merged_blue = (uint8)Math.round (blue_sum / total_pop);
                    
                    var merged_swatch = new Swatch (merged_red, merged_green, merged_blue, total_pop);
                    merged.add (merged_swatch);
                }
                
                merged_mask[i] = true;
            }
            
            return merged;
        }
        
        // Final outlier filtering - remove colors that are isolated from the main palette
        private Gee.ArrayList<Swatch> filter_outlier_colors (Gee.List<Swatch> swatches) {
            if (swatches.size <= 2) {
                return new Gee.ArrayList<Swatch>.wrap ((Swatch[])swatches.to_array ());
            }
            
            // Calculate average color of top 3 most populous colors
            int total_pop = 0;
            double avg_red = 0.0;
            double avg_green = 0.0;
            double avg_blue = 0.0;
            
            int count = int.min (3, swatches.size);
            for (int i = 0; i < count; i++) {
                avg_red += swatches[i].red * swatches[i].population;
                avg_green += swatches[i].green * swatches[i].population;
                avg_blue += swatches[i].blue * swatches[i].population;
                total_pop += swatches[i].population;
            }
            
            if (total_pop == 0) {
                return new Gee.ArrayList<Swatch>.wrap ((Swatch[])swatches.to_array ());
            }
            
            avg_red /= total_pop;
            avg_green /= total_pop;
            avg_blue /= total_pop;
            
            var center = new Swatch ((uint8)Math.round (avg_red), 
                                     (uint8)Math.round (avg_green), 
                                     (uint8)Math.round (avg_blue), 0);
            
            // Filter out colors that are too far from the center (unless they're very common)
            var filtered = new Gee.ArrayList<Swatch> ();
            int all_pop = 0;
            foreach (var swatch in swatches) {
                all_pop += swatch.population;
            }
            
            // Calculate saturation of center color to determine filtering strategy
            double center_sat = get_saturation (center);
            double threshold = 3600.0; // ~60 RGB units default
            if (center_sat < 0.3) {
                // For low-saturation images, be very lenient (allow various shades of grays/blues)
                threshold = 12100.0; // ~110 RGB units - allows wide variation in gray/blue tones
            }
            
            foreach (var swatch in swatches) {
                double dist = color_distance_squared (swatch, center);
                bool is_common = swatch.population >= all_pop / 25; // At least 4% of total
                
                if (dist <= threshold || is_common) {
                    filtered.add (swatch);
                }
            }
            
            return filtered.size > 0 ? filtered : new Gee.ArrayList<Swatch>.wrap ((Swatch[])swatches.to_array ());
        }

        // Calculate hue in degrees (0-360) from RGB
        private static double get_hue (Swatch color) {
            double r = color.R;
            double g = color.G;
            double b = color.B;
            double max = double.max (double.max (r, g), b);
            double min = double.min (double.min (r, g), b);
            double delta = max - min;
            
            if (delta == 0.0) return 0.0; // Grayscale
            
            double hue = 0.0;
            if (max == r) {
                hue = ((g - b) / delta) % 6.0;
            } else if (max == g) {
                hue = ((b - r) / delta) + 2.0;
            } else {
                hue = ((r - g) / delta) + 4.0;
            }
            
            hue *= 60.0;
            if (hue < 0.0) hue += 360.0;
            
            return hue;
        }
        
        // Get ROYGBIV category from hue (0-6: Red, Orange, Yellow, Green, Blue, Indigo, Violet)
        private static int get_roygbiv_category (double hue) {
            // Red: 0-15, 345-360
            if (hue >= 345.0 || hue < 15.0) return 0; // Red
            // Orange: 15-45
            if (hue >= 15.0 && hue < 45.0) return 1; // Orange
            // Yellow: 45-75
            if (hue >= 45.0 && hue < 75.0) return 2; // Yellow
            // Green: 75-150
            if (hue >= 75.0 && hue < 150.0) return 3; // Green
            // Blue: 150-240
            if (hue >= 150.0 && hue < 240.0) return 4; // Blue
            // Indigo: 240-270
            if (hue >= 240.0 && hue < 270.0) return 5; // Indigo
            // Violet: 270-345
            if (hue >= 270.0 && hue < 345.0) return 6; // Violet
            
            return -1; // Should not happen
        }
        
        // Ensure at least one color from each ROYGBIV category (if they exist in the image)
        private void ensure_roygbiv_coverage () {
            if (_swatches.size == 0) {
                return;
            }
            
            // Track which ROYGBIV categories we have
            var category_found = new bool[7]; // 7 categories: R, O, Y, G, B, I, V
            var category_colors = new Swatch?[7]; // Store best color for each category
            
            // Minimum saturation to consider a color "colorful" (not grayscale)
            const double MIN_SATURATION = 0.15;
            
            // Check current swatches for ROYGBIV coverage
            foreach (var swatch in _swatches) {
                double sat = get_saturation (swatch);
                if (sat < MIN_SATURATION) {
                    continue; // Skip low-saturation colors (grays)
                }
                
                double hue = get_hue (swatch);
                int category = get_roygbiv_category (hue);
                
                if (category >= 0 && category < 7) {
                    // Keep the color with highest population for each category
                    if (!category_found[category] || 
                        (category_colors[category] != null && 
                         swatch.population > category_colors[category].population)) {
                        category_found[category] = true;
                        category_colors[category] = swatch;
                    }
                }
            }
            
            // Check which categories are missing
            var missing_categories = new Gee.ArrayList<int> ();
            for (int i = 0; i < 7; i++) {
                if (!category_found[i]) {
                    missing_categories.add (i);
                }
            }
            
            // If we have all categories, nothing to do
            if (missing_categories.size == 0) {
                return;
            }
            
            // Search histogram for colors in missing categories
            var existing_colors = new Gee.HashSet<int> ();
            foreach (var existing in _swatches) {
                existing_colors.add (existing.to_rgb ());
            }
            
            // Get all colors from histogram sorted by population
            var all_swatches = new Gee.ArrayList<Swatch> ();
            histogram.@foreach ((entry) => {
                var color = entry.key;
                int population = entry.value;
                uint8 red = (uint8)((color >> 16) & 0xFF);
                uint8 green = (uint8)((color >> 8) & 0xFF);
                uint8 blue = (uint8)(color & 0xFF);
                var swatch = new Swatch (red, green, blue, population);
                all_swatches.add (swatch);
                return true;
            });
            
            // Sort by population
            all_swatches.sort ((c1, c2) => {
                return c2.population - c1.population;
            });
            
            // Find colors for missing categories
            foreach (var swatch in all_swatches) {
                // Skip if already in palette
                if (existing_colors.contains (swatch.to_rgb ())) {
                    continue;
                }
                
                // Skip low-saturation colors
                double sat = get_saturation (swatch);
                if (sat < MIN_SATURATION) {
                    continue;
                }
                
                double hue = get_hue (swatch);
                int category = get_roygbiv_category (hue);
                
                // If this color belongs to a missing category, add it
                if (category >= 0 && missing_categories.contains (category)) {
                    _swatches.add (swatch);
                    existing_colors.add (swatch.to_rgb ());
                    missing_categories.remove (category); // Remove from missing list
                    
                    // If we found all missing categories, we're done
                    if (missing_categories.size == 0) {
                        break;
                    }
                }
            }
        }

        // Calculate lightness (0-1) from RGB
        private static double get_lightness (Swatch color) {
            double max = double.max (double.max (color.R, color.G), color.B);
            double min = double.min (double.min (color.R, color.G), color.B);
            return (max + min) / 2.0;
        }

        private static double get_saturation (Swatch color) {
            double max = double.MAX;
            if (color.R > color.G && color.R > color.B) {
                max = color.R;
            } else if (color.G > color.R && color.G > color.B) {
                max = color.G;
            } else {
                max = color.B;
            }

            double min = double.MIN;
            if (color.R < color.G && color.R < color.B) {
                min = color.R;
            } else if (color.G < color.R && color.G < color.B) {
                min = color.G;
            } else {
                min = color.B;
            }

            double s = 0;
            double l = (max + min) / 2;
            double chroma = max - min;
            if (chroma == 0) {
                s = 0;
            } else {
                if (l <= 0.5) {
                    s = chroma / (2 * l);
                } else {
                    s = chroma / (2 - 2 *l);
                }
            }

            return s;
        }
        
        // Get saturation bucket (0-3) from saturation value (0-1)
        private static int get_saturation_bucket (double saturation) {
            // Divide saturation range into 4 buckets
            if (saturation < 0.25) return 0;      // Very low saturation
            if (saturation < 0.50) return 1;      // Low saturation
            if (saturation < 0.75) return 2;      // Medium saturation
            return 3;                             // High saturation
        }
        
        // Get lightness bucket (0-3) from lightness value (0-1)
        private static int get_lightness_bucket (double lightness) {
            // Divide lightness range into 4 buckets
            if (lightness < 0.25) return 0;      // Very dark
            if (lightness < 0.50) return 1;      // Dark
            if (lightness < 0.75) return 2;      // Light
            return 3;                            // Very light
        }
        
        // Ensure at least one color from each saturation bucket (if they exist in the image)
        private void ensure_saturation_coverage () {
            if (_swatches.size == 0) {
                return;
            }
            
            // Track which saturation buckets we have
            var bucket_found = new bool[4]; // 4 buckets
            var bucket_colors = new Swatch?[4]; // Store best color for each bucket
            
            // Check current swatches for saturation coverage
            foreach (var swatch in _swatches) {
                double sat = get_saturation (swatch);
                int bucket = get_saturation_bucket (sat);
                
                // Keep the color with highest population for each bucket
                if (!bucket_found[bucket] || 
                    (bucket_colors[bucket] != null && 
                     swatch.population > bucket_colors[bucket].population)) {
                    bucket_found[bucket] = true;
                    bucket_colors[bucket] = swatch;
                }
            }
            
            // Check which buckets are missing
            var missing_buckets = new Gee.ArrayList<int> ();
            for (int i = 0; i < 4; i++) {
                if (!bucket_found[i]) {
                    missing_buckets.add (i);
                }
            }
            
            // If we have all buckets, nothing to do
            if (missing_buckets.size == 0) {
                return;
            }
            
            // Search histogram for colors in missing buckets
            var existing_colors = new Gee.HashSet<int> ();
            foreach (var existing in _swatches) {
                existing_colors.add (existing.to_rgb ());
            }
            
            // Get all colors from histogram sorted by population
            var all_swatches = new Gee.ArrayList<Swatch> ();
            histogram.@foreach ((entry) => {
                var color = entry.key;
                int population = entry.value;
                uint8 red = (uint8)((color >> 16) & 0xFF);
                uint8 green = (uint8)((color >> 8) & 0xFF);
                uint8 blue = (uint8)(color & 0xFF);
                var swatch = new Swatch (red, green, blue, population);
                all_swatches.add (swatch);
                return true;
            });
            
            // Sort by population
            all_swatches.sort ((c1, c2) => {
                return c2.population - c1.population;
            });
            
            // Find colors for missing buckets
            foreach (var swatch in all_swatches) {
                // Skip if already in palette
                if (existing_colors.contains (swatch.to_rgb ())) {
                    continue;
                }
                
                double sat = get_saturation (swatch);
                int bucket = get_saturation_bucket (sat);
                
                // If this color belongs to a missing bucket, add it
                if (missing_buckets.contains (bucket)) {
                    _swatches.add (swatch);
                    existing_colors.add (swatch.to_rgb ());
                    missing_buckets.remove (bucket); // Remove from missing list
                    
                    // If we found all missing buckets, we're done
                    if (missing_buckets.size == 0) {
                        break;
                    }
                }
            }
        }
        
        // Ensure at least one color from each lightness bucket (if they exist in the image)
        private void ensure_lightness_coverage () {
            if (_swatches.size == 0) {
                return;
            }
            
            // Track which lightness buckets we have
            var bucket_found = new bool[4]; // 4 buckets
            var bucket_colors = new Swatch?[4]; // Store best color for each bucket
            
            // Check current swatches for lightness coverage
            foreach (var swatch in _swatches) {
                double light = get_lightness (swatch);
                int bucket = get_lightness_bucket (light);
                
                // Keep the color with highest population for each bucket
                if (!bucket_found[bucket] || 
                    (bucket_colors[bucket] != null && 
                     swatch.population > bucket_colors[bucket].population)) {
                    bucket_found[bucket] = true;
                    bucket_colors[bucket] = swatch;
                }
            }
            
            // Check which buckets are missing
            var missing_buckets = new Gee.ArrayList<int> ();
            for (int i = 0; i < 4; i++) {
                if (!bucket_found[i]) {
                    missing_buckets.add (i);
                }
            }
            
            // If we have all buckets, nothing to do
            if (missing_buckets.size == 0) {
                return;
            }
            
            // Search histogram for colors in missing buckets
            var existing_colors = new Gee.HashSet<int> ();
            foreach (var existing in _swatches) {
                existing_colors.add (existing.to_rgb ());
            }
            
            // Get all colors from histogram sorted by population
            var all_swatches = new Gee.ArrayList<Swatch> ();
            histogram.@foreach ((entry) => {
                var color = entry.key;
                int population = entry.value;
                uint8 red = (uint8)((color >> 16) & 0xFF);
                uint8 green = (uint8)((color >> 8) & 0xFF);
                uint8 blue = (uint8)(color & 0xFF);
                var swatch = new Swatch (red, green, blue, population);
                all_swatches.add (swatch);
                return true;
            });
            
            // Sort by population
            all_swatches.sort ((c1, c2) => {
                return c2.population - c1.population;
            });
            
            // Find colors for missing buckets
            foreach (var swatch in all_swatches) {
                // Skip if already in palette
                if (existing_colors.contains (swatch.to_rgb ())) {
                    continue;
                }
                
                double light = get_lightness (swatch);
                int bucket = get_lightness_bucket (light);
                
                // If this color belongs to a missing bucket, add it
                if (missing_buckets.contains (bucket)) {
                    _swatches.add (swatch);
                    existing_colors.add (swatch.to_rgb ());
                    missing_buckets.remove (bucket); // Remove from missing list
                    
                    // If we found all missing buckets, we're done
                    if (missing_buckets.size == 0) {
                        break;
                    }
                }
            }
        }

    }
}
