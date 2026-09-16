package com.arena.backend.configuration;

import jakarta.servlet.DispatcherType;

import com.arena.backend.web.RequestLoggingFilter;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

@Configuration(proxyBeanMethods = false)
public class RequestLoggingConfiguration {

	@Bean
	FilterRegistrationBean<RequestLoggingFilter> requestLoggingFilter() {
		var registration = new FilterRegistrationBean<>(new RequestLoggingFilter());
		registration.setOrder(Ordered.HIGHEST_PRECEDENCE);
		registration.setDispatcherTypes(DispatcherType.REQUEST, DispatcherType.ERROR);
		return registration;
	}
}
