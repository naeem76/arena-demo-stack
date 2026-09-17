package com.arena.backend.web;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
class AuthPageController {

	@GetMapping("/login")
	String login() {
		return "auth/login";
	}

	@GetMapping("/logout")
	String logout() {
		return "auth/logout";
	}
}
