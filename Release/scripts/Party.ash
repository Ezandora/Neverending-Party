string __party_version = "1.0";

boolean [int][int] parseSavedPartyChoices()
{
	boolean [int][int] party_choices_taken;
	string [int] choices_level_1 = get_property("_neverendingPartyChoicesTakenToday").split_string("\\|");
	foreach key, choice_unparsed in choices_level_1
	{
		string [int] choices_level_2 = choice_unparsed.split_string(",");
		if (choices_level_2.count() != 2) continue;
		party_choices_taken[choices_level_2[0].to_int()][choices_level_2[1].to_int()] = true;
	}
	return party_choices_taken;
}

void savePartyChoices(boolean [int][int] party_choices_taken)
{
	buffer out;
	foreach choice_id in party_choices_taken
	{
		foreach option in party_choices_taken[choice_id]
		{
			if (out.length() != 0)
				out.append("|");
			out.append(choice_id);
			out.append(",");
			out.append(option);
		}
	}
	set_property("_neverendingPartyChoicesTakenToday", out);
}

void main(string arguments)
{
	arguments = arguments.to_lower_case();
	
	if (arguments == "help")
	{
		print_html("Party v" + __party_version);
		print_html("<b>free</b>: only complete free fights");
		print_html("<b>quest</b>: complete quest (on by default)");
		print_html("<b>noquest</b>: only complete free fights, do not start quest (best for in-run)");
		print_html("<b>hard</b>: hard mode, if available");
		//print_html("<b>mall</b>: open favors and sell results in mall"); //not yet written
		print_html("");
		print_html("Example usage:");
		print_html("<b>party</b>: complete quest");
		print_html("<b>party hard</b>: complete hard mode quest");
		print_html("<b>party noquest</b>: use when in-run");
		return;
	}
	if (property_exists("_questPartyFair") && (get_property("_questPartyFair") == "finished" || get_property("_questPartyFair") == ""))
	{
		print_html("Quest done for the day.");
		return;
	}
	
	boolean start_quest = true;
	boolean only_do_free_fights = false;
	boolean complete_quest = true;
	boolean hard_mode = false;
	boolean sell_gains = false;
	
	string [int] arguments_words = arguments.split_string(" ");
	foreach key, word in arguments_words
	{
		if (word == "quest")
		{
			only_do_free_fights = false;
			complete_quest = true;
		}
		if (word == "free")
		{
			only_do_free_fights = true;
			complete_quest = false;
		}
		if (word == "hard")
			hard_mode = true;
		if (word == "noquest")
		{
			start_quest = false;
			complete_quest = false;
			only_do_free_fights = true;
		}
		if (word == "mall")
		{
			//FIXME write this
			sell_gains = true;
			//FIXME do hard mode if the rewards are better on average
		}
		//FIXME buffs/statgain:
	}
	
	if ($item[PARTY HARD T-shirt].available_amount() == 0)
	{
		hard_mode = false;
	}
	
	boolean [int][int] party_choices_taken = parseSavedPartyChoices();
	
	int active_quest = -1;
	int quest_substate = -1;
	
	string last_maximisation = "";
	
	item item_wanted = $item[none];
	int item_wanted_amount = 0;
	
	int QUEST_TYPE_DJ = 1;
	int QUEST_TYPE_CLEAR_OUT_GUESTS = 2;
	int QUEST_TYPE_GERALD = 3;
	int QUEST_TYPE_GERALDINE = 4;
	int QUEST_TYPE_HYPE = 5;
	int QUEST_TYPE_TRASH = 6;
	int QUEST_TYPE_NEARLY_COMPLETED = 7;
	
	int breakout = 100;
	while (breakout > 0)
	{
		breakout -= 1;
		
		if (only_do_free_fights)
		{
			//Check if we have free fights left:
			buffer town_wrong_page_text = visit_url("place.php?whichplace=town_wrong");
			if (!town_wrong_page_text.contains_text("town/nparty_free.gif"))
			{
				print_html("Done with free fights.");
				break;
			}
		}
		if (property_exists("_questPartyFair"))
		{
			string quest_state_string = get_property("_questPartyFair");
			if (quest_state_string == "finished" || quest_state_string == "")
			{
				print_html("Done with quest.");
				break;
			}
		}
		if (start_quest)
		{
			set_property("choiceAdventure1322", 1);
		}
		else
		{
			set_property("choiceAdventure1322", 2);
		}
		
		if (complete_quest && active_quest == -1)
		{
			buffer quest_log_text = visit_url("questlog.php?which=7");
			string partial_match = quest_log_text.group_string("<p><b>Party Fair</b>(.*?)<p>")[0][1];
			
			if (partial_match == "")
			{
				//not started yet
			}
			else if (partial_match.contains_text("Return to the") && partial_match.contains_text("for your reward"))
			{
				active_quest = QUEST_TYPE_NEARLY_COMPLETED;
			}
			else if (partial_match.contains_text("Collect Meat for the DJ"))
			{
				active_quest = QUEST_TYPE_DJ;
			}
			else if (partial_match.contains_text("Clear all of the guests out of the"))
			{
				active_quest = QUEST_TYPE_CLEAR_OUT_GUESTS;
			}
			else if (partial_match.contains_text("Clean up the trash at the"))
			{
				active_quest = QUEST_TYPE_TRASH;
			}
			else if (partial_match.contains_text("see what kind of booze Gerald wants"))
			{
				active_quest = QUEST_TYPE_GERALD;
				quest_substate = 0;
			}
			else if (partial_match.contains_text("to see what kind of snacks Geraldine wants"))
			{
				active_quest = QUEST_TYPE_GERALDINE;
				quest_substate = 0;
			}
			else if (partial_match.contains_text("for Gerald at the") || partial_match.contains_text("for Geraldine at the") || partial_match.contains_text("to Geraldine in the kitchen"))
			{
				if (partial_match.contains_text("Geraldine"))
					active_quest = QUEST_TYPE_GERALDINE;
				else
					active_quest = QUEST_TYPE_GERALD;
				quest_substate = 1;
				//Parse the one we want:
				string [int][int] matches;
				if (active_quest == QUEST_TYPE_GERALD)
					matches = partial_match.group_string("Get ([0-9]+) (.*?) for Gerald at the");
				else
					matches = partial_match.group_string("Get ([0-9]+) (.*?) for Geraldine at the");
				if (matches.count() == 0)
					matches = partial_match.group_string("Take the ([0-9]+) (.*?) to Geraldine in the kitchen");
				int amount_wanted = matches[0][1].to_int();
				string plural_wanted = matches[0][2];
				item_wanted_amount = amount_wanted;
				//Convert plural back:
				foreach it in $items[]
				{
					if (it.plural == plural_wanted)
					{
						item_wanted = it;
						break;
					}
				}
				print("Want " + item_wanted_amount + " of " + item_wanted + " (assumed match against plural \"" + plural_wanted + "\")");
			}
			else if (partial_match.contains_text("started!") && partial_match.contains_text("Hype level:"))
			{
				active_quest = QUEST_TYPE_HYPE;
			}
			else
				abort("unknown partial match = \"" + partial_match.entity_encode() + "\"");
		}
		
		string maximisation_command;
		if (active_quest == QUEST_TYPE_DJ || !can_interact())
			maximisation_command = "meat";
		else
			maximisation_command = "item";
		
		if (active_quest == QUEST_TYPE_CLEAR_OUT_GUESTS)
		{
			if ($item[intimidating chainsaw].available_amount() > 0)
				maximisation_command += " +equip intimidating chainsaw";
			
		}
		if (active_quest == QUEST_TYPE_HYPE)
		{
			if ($item[cosmetic football].available_amount() > 0)
				maximisation_command += " +equip cosmetic football";
		}
		if (inebriety_limit() - my_inebriety() < 0)
		{
			if ($item[drunkula's wineglass].available_amount() > 0 && $item[drunkula's wineglass].can_equip())
			{
				maximisation_command += " +equip drunkula's wineglass";
			}
			else
			{
				print_html("Overdrunk");
				break;
			}
		}
		if (hard_mode)
			maximisation_command += " +equip PARTY HARD T-shirt";
		maximisation_command += " -equip broken champagne bottle";
		if (last_maximisation != maximisation_command)
		{
			maximize(maximisation_command, false);
			last_maximisation = maximisation_command;
		}
		
		//Items:
		if (item_wanted != $item[none] && can_interact() && item_wanted_amount < 100)
		{
			retrieve_item(item_wanted_amount, item_wanted);
			//FIXME if not in ronin, use that one item
		}
		//Choice adventure:
		int [int] choices;
		choices[1324] = 5; //like all things in life; if we run out of ideas, fight.
		if (active_quest == QUEST_TYPE_CLEAR_OUT_GUESTS)
		{
			if ($item[intimidating chainsaw].available_amount() == 0)
			{
				choices[1324] = 4;
				choices[1328] = 3;
			}
			else if (!party_choices_taken[1325][3] && $item[jam band bootleg].item_amount() > 0)
			{
				choices[1324] = 1;
				choices[1325] = 3;
			}
			else if (!party_choices_taken[1327][5] && $item[purple beast energy drink].item_amount() > 0)
			{
				//should we even...?
				choices[1324] = 3;
				choices[1327] = 5;
			}
		}
		if (active_quest == QUEST_TYPE_GERALD)
		{
			choices[1324] = 3;
			if (quest_substate == 0)
				choices[1327] = 3;
			else
				choices[1327] = 4;
		}
		if (active_quest == QUEST_TYPE_GERALDINE)
		{
			choices[1324] = 2;
			if (quest_substate == 0)
				choices[1326] = 3;
			else
				choices[1326] = 4;
			
		}
		if (active_quest == QUEST_TYPE_TRASH)
		{
			if (!party_choices_taken[1326][5])
			{
				//Is this even worth it? Last time I tried it, it did 81 pieces of trash. Fights did more than that, I think.
				choices[1324] = 2; //kitchen
				choices[1326] = 5; //burn some trash
			}
			else
				choices[1324] = 5; //fight!
		}
		if (active_quest == QUEST_TYPE_DJ)
		{
			if (my_buffedstat($stat[moxie]) >= 300)
			{
				choices[1324] = 1;
				choices[1325] = 4;
			}
		}
		if (active_quest == QUEST_TYPE_HYPE)
		{
			if (!party_choices_taken[1328][4] && $item[electronics kit].item_amount() > 0)
			{
				choices[1324] = 4;
				choices[1328] = 4;
			}
			//else little red dress
			else if (!party_choices_taken[1325][5] && $item[very small red dress].item_amount() > 0)
			{
				choices[1324] = 1;
				choices[1325] = 5;
			}
		}
		
		foreach choice_id, option in choices
			set_property("choiceAdventure" + choice_id, option);
		boolean successish = adv1($location[the neverending party], 0, "");
		
		string last_encounter = get_property("lastEncounter");
		if (last_encounter == "All Done!" || last_encounter == "Party's Over" || !successish)
		{
			print_html("Done with quest.");
			break;
		}
		if (last_encounter == "Forward to the Back" || last_encounter == "Gone Kitchin'")
		{
			//reparse quest state, for Gerald/Geraldine:
			active_quest = -1;
			quest_substate = -1;
		}
		//Store last_choice() and last_decision(), for quests:
		
		party_choices_taken[last_choice()][last_decision()] = true;
		savePartyChoices(party_choices_taken);
	}
	
	if (sell_gains)
	{
		//Open party favors we gained, sell:
		
	}
}