// Autor: Manuel Ros Rodriguez

// Modulos y constantes
const Web3 = require('web3');
const { setupLoader } = require('@openzeppelin/contract-loader');
const fs = require('fs');
const url = require('url');
const hostname = '0.0.0.0';
const port = 80;
const express = require('express');
const app = express();

const net = require('net');
const web3 = new Web3('/Users/manolo/tfgugr/geth.ipc', net);

const direccionAccesoBlockchain = '0xB29eaA341A97fb2567cd1640eDed8edc3eA0f45e';
const direccionAlmacenes = '0xbbfB6C8C621292847b943817A3392E258B5e267b';
const direccionComunidadesAutonomas = '0xA6eD9E0Ee57F091d06C089534ACaDb164DFD3b31';
const direccionSuministrosMedicos = '0xa0ea1235976227269F1A019DAFd472b925125513';
const direccionTrazabilidadSuministros = '0xaF98Cb06018E5A0Fc1F9b92692E6B39dAA653198';

const cuentaAutorizada = '0x2594A47C8704d2Cf3C1A06a7105A13c16932a0Fa';

const loader = setupLoader({ provider: web3 }).web3;
const AccesoBlockchain = loader.fromArtifact('AccesoBlockchain', direccionAccesoBlockchain);
const SuministrosMedicos = loader.fromArtifact('SuministrosMedicos', direccionSuministrosMedicos);
const Almacenes = loader.fromArtifact('Almacenes', direccionAlmacenes);
const ComunidadesAutonomas = loader.fromArtifact('ComunidadesAutonomas', direccionComunidadesAutonomas);
const TrazabilidadSuministros = loader.fromArtifact('TrazabilidadSuministros', direccionTrazabilidadSuministros);

// Funciones

/**
 * Inicializa el contrato AccesoBlockchain, pasandole las direcciones de los contratos
 * con los que se va a comunicar
 *
 */
function inicializarAccesoBlockchain() {
	AccesoBlockchain.methods.inicializar(direccionAlmacenes, direccionComunidadesAutonomas,
		 direccionSuministrosMedicos, direccionTrazabilidadSuministros)
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('AccesoBlockchain error: '+err);
			process.exit(1);
		} else
			inicializarSuministrosMedicos();
	});
}

/**
 * Inicializa el contrato SuministrosMedicos, pasandole las direcciones de los contratos
 * con los que se va a comunicar
 *
 */
function inicializarSuministrosMedicos() {
	SuministrosMedicos.methods.inicializar(direccionAlmacenes, direccionTrazabilidadSuministros,
		direccionComunidadesAutonomas, direccionAccesoBlockchain)
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('SuministrosMedicos error: '+err);
			process.exit(1);
		} else
			inicializarAlmacenes();
	});
}

/**
 * Inicializa el contrato Almacenes, pasandole las direcciones de los contratos
 * con los que se va a comunicar
 *
 */
function inicializarAlmacenes() {
	Almacenes.methods.inicializar(direccionSuministrosMedicos, direccionComunidadesAutonomas,
		direccionAccesoBlockchain)
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('Almacenes error: '+err);
			process.exit(1);
		} else
			inicializarTrazabilidadSuministros();
	});
}

/**
 * Inicializa el contrato TrazabilidadSuministros, pasandole las direcciones de los contratos
 * con los que se va a comunicar
 *
 */
function inicializarTrazabilidadSuministros() {
	TrazabilidadSuministros.methods.inicializar(direccionSuministrosMedicos,
		direccionAccesoBlockchain)
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('TrazabilidadSuministros error: '+err);
			process.exit(1);
		} else
			inicializarComunidadesAutonomas();
	});
}

/**
 * Inicializa el contrato ComunidadesAutonomas, pasandole las direcciones de los contratos
 * con los que se va a comunicar
 *
 */
function inicializarComunidadesAutonomas() {
	ComunidadesAutonomas.methods.inicializar(direccionAlmacenes, direccionSuministrosMedicos,
		direccionAccesoBlockchain)
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('ComunidadesAutonomas error: '+err);
			process.exit(1);
		} else
			continuarAccesoBlockchain();
	});
}

/**
 * Inicia el contrato AccesoBlockchain, por lo que empezara a aceptar llamadas a sus
 * metodos con modificador puedeParar
 *
 */
function continuarAccesoBlockchain() {
	AccesoBlockchain.methods.continuarContrato()
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('continuarAccesoBlockchain error: '+err);
			process.exit(1);
		} else
			continuarSuministrosMedicos();
	});
}

/**
 * Inicia el contrato SuministrosMedicos, por lo que empezara a aceptar llamadas a sus
 * metodos con modificador puedeParar
 *
 */
function continuarSuministrosMedicos() {
	SuministrosMedicos.methods.continuarContrato()
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('continuarSuministrosMedicos error: '+err);
			process.exit(1);
		} else
			continuarAlmacenes();
	});
}

/**
 * Inicia el contrato Almacenes, por lo que empezara a aceptar llamadas a sus
 * metodos con modificador puedeParar
 *
 */
function continuarAlmacenes() {
	Almacenes.methods.continuarContrato()
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('continuarAlmacenes error: '+err);
			process.exit(1);
		} else
			continuarTrazabilidadSuministros();
	});
}

/**
 * Inicia el contrato TrazabilidadSuministros, por lo que empezara a aceptar llamadas a sus
 * metodos con modificador puedeParar
 *
 */
function continuarTrazabilidadSuministros() {
	TrazabilidadSuministros.methods.continuarContrato()
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('continuarTrazabilidadSuministros error: '+err);
			process.exit(1);
		} else
			continuarComunidadesAutonomas();
	});
}

/**
 * Inicia el contrato ComunidadesAutonomas, por lo que empezara a aceptar llamadas a sus
 * metodos con modificador puedeParar
 *
 */
function continuarComunidadesAutonomas() {
	ComunidadesAutonomas.methods.continuarContrato()
	.send({ from: cuentaAutorizada, gas:500000 }, function(err, data){
		if (err) {
			console.log('continuarComunidadesAutonomas error: '+err);
			process.exit(1);
		} else {
			console.log('Inicializacion de contratos correcta');
			process.exit(0);
		}
	});
}

inicializarAccesoBlockchain();
