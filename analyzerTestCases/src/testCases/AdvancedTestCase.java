package testCases;
import java.util.ArrayList;
public class AdvancedTestCase implements AdvancedTestCaseInterface {
	String firstName;
	public AdvancedTestCase() {
		firstName = "Edward";
	}
	public String getFirstName() {
		return firstName;
	}
	public ArrayList<Integer> infiniteLoop() {
		ArrayList<Integer> list = new ArrayList<>(); 
		for (int i = 0; i < (i + 1); i++) {
			list.add(i);
		}
		return list;
	}
}