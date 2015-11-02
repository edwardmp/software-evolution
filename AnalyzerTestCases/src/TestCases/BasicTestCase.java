package TestCases;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Date;

public class BasicTestCase {
	private String monthString;
	
	public BasicTestCase() {
		Date date = new Date();
		LocalDate localDate = date.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
		int month = localDate.getMonthValue();
	       
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
	
	public String getMonthString() {
		return monthString;
	}
}