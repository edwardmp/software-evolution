public class Test {
   public Test() {
       int month = 8;
       String monthString;
       switch (month) {
           case 1:  
        	   monthString = "January";
                    break;
           case 2:  
        	   monthString = "February";
                    break;
           default: 
        	   monthString = "Invalid month";
                    break;
       }
   }
}