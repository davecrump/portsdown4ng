#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <pigpiod_if2.h>

#include "timer.h"

int8_t IndicationGPIO;          // Broadcom GPIO number for Indication LED (27)
int8_t ButtonGPIO;              // Broadcom GPIO number for Button (22)
bool SDActiveHi;                // true for active high SD (normal), false active low
int pi_handle;                  // handle to access pigpio
_timer_t shutdown_button_timer;

#define PATH_MCONFIG "/home/pi/portsdown/user/configs/main_config.txt"

void GetConfigParam(char *PathConfigFile, char *Param, char *Value);
void Edge_ISR(int pi, unsigned user_gpio, unsigned level, uint32_t tick);
void Shutdown_Function(void);


/***************************************************************************//**
 * @brief Looks up the value of a Param in PathConfigFile and sets value
 *        Used to look up the configuration from dmm_config.txt
 *
 * @param PatchConfigFile (str) the name of the configuration text file
 * @param Param the string labeling the parameter
 * @param Value the looked-up value of the parameter
 *
 * @return void
*******************************************************************************/

void GetConfigParam(char *PathConfigFile, char *Param, char *Value)
{
  char * line = NULL;
  size_t len = 0;
  int read;
  char ParamWithEquals[255];
  strcpy(ParamWithEquals, Param);
  strcat(ParamWithEquals, "=");

  //printf("Get Config reads %s for %s ", PathConfigFile , Param);

  FILE *fp=fopen(PathConfigFile, "r");
  if(fp != 0)
  {
    while ((read = getline(&line, &len, fp)) != -1)
    {
      if(strncmp (line, ParamWithEquals, strlen(Param) + 1) == 0)
      {
        strcpy(Value, line+strlen(Param)+1);
        char *p;
        if((p=strchr(Value,'\n')) !=0 ) *p=0; //Remove \n
        break;
      }
    }
  }
  else
  {
    printf("Config file not found \n");
  }
  fclose(fp);
}


int main( int argc, char *argv[] )
{
  char response[63];

  IndicationGPIO = -1;
  if( argc == 2 )          // Only Button GPIO provided
  {
    ButtonGPIO = atoi(argv[1]);
    if(ButtonGPIO < 0 || ButtonGPIO > 27)
    {
      printf("ERROR: Button GPIO is out of bounds!\n");
      printf("Button GPIO was %d\n", ButtonGPIO);
      return 0;
    }
  }
  else if( argc == 3 )      // Both Button and Indication GPIOs provided
  {
    ButtonGPIO = atoi(argv[1]);
    if(ButtonGPIO < 0 || ButtonGPIO > 27)
    {
      printf("ERROR: Button GPIO is out of bounds!\n");
      printf("Button GPIO was %d\n", ButtonGPIO);
      return 0;
    }
    IndicationGPIO = atoi(argv[2]);
    if(IndicationGPIO < 0 || IndicationGPIO > 27)
    {
      printf("ERROR: Indication GPIO is out of bounds!\n");
      printf("Indication GPIO was %d\n", IndicationGPIO);
      return 0;
    }
  }
  else
  {
    printf("ERROR: Incorrect number of parameters!\n");
    printf(" == pi-sdn == Phil Crump <phil@philcrump.co.uk ==\n");
    printf("          and Dave Crump <dave.g8gkq@gmail.com ==\n");
    printf("  usage: pi-sdn x [y]\n");
    printf("    x: Button GPIO to listen for edge to trigger shutdown.\n");
    printf("    y: Indication GPIO to output HIGH, to detect successful shutdown (optional).\n");
    printf(" ----- \n");
    printf("Notes:\n");
    printf(" * The Button GPIO will be configured with the Pi's internal pullup/down resistor (~50KOhm)\n");
    printf(" * The Indication GPIO will be reset to Input (High-Z) state on Shutdown.\n");
    printf(" * Broadcom GPIO pin numbers are used. (0-27)\n");
    printf("    http://wiringpi.com/pins/\n");
    return 0;
  }

  // Check if button is active high (default), active low or disabled
  strcpy(response, "true");
  SDActiveHi = true;
  GetConfigParam(PATH_MCONFIG, "sdbutton", response);

  if (strcmp(response, "inactive") == 0)
  {
    printf("Shutdown button inactive\n");
    exit(0);
  }

  if ((strcmp(response, "activelo") == 0) || (strcmp(response, "activelow") == 0))
  {
    SDActiveHi = false;
  }
    
  // Initialise pigpio access
  pi_handle = pigpio_start(NULL, NULL);
  if (pi_handle < 0)
  {
    printf("Unable to connect to pigio deamon\n");
    return 1;
  }
  
  // Initialise Indication GPIO
  if(IndicationGPIO >= 0)
  {
    set_mode(pi_handle, IndicationGPIO, PI_OUTPUT);
    gpio_write(pi_handle, IndicationGPIO, 1);
  }

  // Set up Shutdown button GPIO
  set_mode(pi_handle, ButtonGPIO, PI_INPUT);

  CBFunc_t Edge;
  Edge = Edge_ISR;

  if (SDActiveHi == true)       // Shutdown button active high
  {
    set_pull_up_down(pi_handle, ButtonGPIO, PI_PUD_DOWN);
    callback(pi_handle, ButtonGPIO, RISING_EDGE, Edge);
  }
  else                          // Shutdown button active low
  {
    set_pull_up_down(pi_handle, ButtonGPIO, PI_PUD_UP);
    callback(pi_handle, ButtonGPIO, FALLING_EDGE, Edge);
  }

  // Spin loop while waiting for ISR 
  while(1)
  {
    delay(10000);
  }  
  return 0;
}


void Edge_ISR(int pi, unsigned user_gpio, unsigned level, uint32_t tick)
{
  if (SDActiveHi == true)       // Shutdown button active high
  {
    if(gpio_read(pi_handle, ButtonGPIO) == 1)
    {
      // Try to reset the timer in case it is already running
      timer_reset(&shutdown_button_timer);

      // Set timer
      timer_set(&shutdown_button_timer, 100, Shutdown_Function);
    }
    else
    {
      // Disarm timer
      timer_reset(&shutdown_button_timer);
    }
  }
  else                          // Shutdown button active low
  {
    if(gpio_read(pi_handle, ButtonGPIO) == 0)
    {
      // Try to reset the timer in case it is already running
      timer_reset(&shutdown_button_timer);

      // Set timer
      timer_set(&shutdown_button_timer, 100, Shutdown_Function);
    }
    else
    {
      // Disarm timer
      timer_reset(&shutdown_button_timer);
    }
  }
}


void Shutdown_Function(void)
{
  // Shut Down
  printf("Shutdown requested from Shutdown Button\n");
  gpio_write(pi_handle, IndicationGPIO, 0);
  system("/home/pi/portsdown/scripts/shutdown_script.sh &");
  exit(0);
}

