resource "aws_iam_user_group_membership" "example2" {
  user = "${aws_iam_user.example.name}"

  groups = [
    "${aws_iam_group.developers.name}",
	]
	}
	
	
	
       #####  USERS #####

resource "aws_iam_user" "example" {
  name = "artech"
  }
  
  
  
       #####  Group #####
  
 resource "aws_iam_group" "developers" {
  name = "developers"
  }