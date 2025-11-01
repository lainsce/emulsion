namespace Emulsion {
    public class CollectionInfo : Object {
        /*
         * name : string of the Collection's name e.g. "Summer Theme";
         * palette_names : list of palette names that belong to this collection
         */
        public string name { get; set; }
        public Gee.ArrayList<string> palette_names { get; set; }
        
        public CollectionInfo () {
            palette_names = new Gee.ArrayList<string> ();
        }
    }

    public class RecentColorInfo : Object {
        /*
         * name : string of the Color name, e.g. "White";
         * color : string of the Color color, in hexcode, e.g. "#FFFFFF";
         * timestamp : when this color was last accessed/created
         */
        public string name { get; set; }
        public string color { get; set; }
        public int64 timestamp { get; set; }
        
        public RecentColorInfo (string name, string color) {
            this.name = name;
            this.color = color;
            this.timestamp = get_real_time ();
        }
    }
}

